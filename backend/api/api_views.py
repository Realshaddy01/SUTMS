"""
API views for the SUTMS application.
"""
import os
import stripe
import logging
from django.conf import settings
from django.contrib.auth import get_user_model, authenticate, login, logout
from django.db.models import Q, Count, Sum, TruncMonth
from django.shortcuts import get_object_or_404, render
from rest_framework import viewsets, permissions, status, filters
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.authtoken.models import Token
from rest_framework.permissions import IsAuthenticated, AllowAny
from django.utils import timezone
from datetime import timedelta

from accounts.models import UserProfile, User
from vehicles.models import Vehicle, VehicleDocument
from violations.models import Violation, ViolationType, ViolationAppeal, Notification
from payments.models import Payment, PaymentReceipt
from ocr.models import LicensePlateDetection, TrainingImage
from ocr.utils import detect_license_plate

from .serializers import (
    UserSerializer, UserProfileSerializer, VehicleSerializer, 
    VehicleDocumentSerializer, ViolationTypeSerializer, ViolationSerializer,
    ViolationAppealSerializer, PaymentSerializer, PaymentReceiptSerializer,
    LicensePlateDetectionSerializer, TrainingImageSerializer, RegisterSerializer,
    NotificationSerializer
)
from .permissions import (
    IsOwnerOrReadOnly, IsOfficerOrAdmin, IsAdminUser, IsVehicleOwner,
    IsReportingOfficer, IsViolationVehicleOwner
)

User = get_user_model()
logger = logging.getLogger('sutms.api')

# Initialize Stripe
stripe.api_key = settings.STRIPE_SECRET_KEY


class UserViewSet(viewsets.ModelViewSet):
    """API endpoint for users"""
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, DjangoFilterBackend]
    search_fields = ['email', 'username', 'first_name', 'last_name']
    filterset_fields = ['user_type', 'is_active']
    
    def get_queryset(self):
        # Regular users can only see their own profile
        # Officers and admins can see all profiles
        user = self.request.user
        if user.is_admin():
            return User.objects.all()
        elif user.is_officer():
            return User.objects.filter(Q(id=user.id) | Q(user_type='vehicle_owner'))
        return User.objects.filter(id=user.id)
    
    def get_permissions(self):
        if self.action in ['create', 'destroy']:
            return [permissions.IsAdminUser()]
        return super().get_permissions()
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        """Get current user's profile"""
        return Response(self.get_serializer(request.user).data)
    
    @action(detail=False, methods=['put', 'patch'])
    def update_profile(self, request):
        """Update current user's profile"""
        user = request.user
        serializer = self.get_serializer(user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    
    @action(detail=False, methods=['post'])
    def update_fcm_token(self, request):
        """Update user's Firebase Cloud Messaging token"""
        user = request.user
        token = request.data.get('token')
        
        if not token:
            return Response({'error': 'FCM token is required'}, 
                           status=status.HTTP_400_BAD_REQUEST)
            
        user.firebase_token = token
        user.save()
        return Response({'success': True})


class VehicleViewSet(viewsets.ModelViewSet):
    """API endpoint for vehicles"""
    queryset = Vehicle.objects.all()
    serializer_class = VehicleSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrReadOnly]
    filter_backends = [filters.SearchFilter, DjangoFilterBackend]
    search_fields = ['license_plate', 'make', 'model', 'registration_number']
    filterset_fields = ['vehicle_type', 'owner']
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_admin:
            return Vehicle.objects.all()
        elif user.is_officer:
            return Vehicle.objects.all()
        
        # For vehicle owners, filter by their VehicleOwner object
        try:
            vehicle_owner = user.vehicle_owner
            return Vehicle.objects.filter(owner=vehicle_owner)
        except AttributeError:
            # If user doesn't have a vehicle_owner relationship
            return Vehicle.objects.none()
    
    def perform_create(self, serializer):
        # Set owner to current user if not specified
        if 'owner' not in serializer.validated_data:
            serializer.save(owner=self.request.user)
        else:
            serializer.save()
    
    @action(detail=False, methods=['get'])
    def my_vehicles(self, request):
        """Get vehicles owned by the current user"""
        try:
            vehicle_owner = request.user.vehicle_owner
            vehicles = Vehicle.objects.filter(owner=vehicle_owner)
        except AttributeError:
            vehicles = Vehicle.objects.none()
            
        page = self.paginate_queryset(vehicles)
        
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(vehicles, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def search_by_plate(self, request):
        """Search for vehicles by license plate"""
        plate = request.query_params.get('plate', '')
        if not plate:
            return Response({'error': 'License plate parameter is required'}, 
                           status=status.HTTP_400_BAD_REQUEST)
            
        vehicles = Vehicle.objects.filter(license_plate__icontains=plate)
        serializer = self.get_serializer(vehicles, many=True)
        return Response(serializer.data)


class VehicleDocumentViewSet(viewsets.ModelViewSet):
    """API endpoint for vehicle documents"""
    queryset = VehicleDocument.objects.all()
    serializer_class = VehicleDocumentSerializer
    permission_classes = [permissions.IsAuthenticated, IsVehicleOwner]
    parser_classes = [MultiPartParser, FormParser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['vehicle', 'document_type', 'is_verified']
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_admin:
            return VehicleDocument.objects.all()
        elif user.is_officer:
            return VehicleDocument.objects.all()
        return VehicleDocument.objects.filter(vehicle__owner=user)
    
    @action(detail=True, methods=['post'], permission_classes=[IsOfficerOrAdmin])
    def verify(self, request, pk=None):
        """Verify a vehicle document (officer/admin only)"""
        document = self.get_object()
        document.is_verified = True
        document.verified_by = request.user
        document.verification_date = timezone.now()
        document.save()
        
        serializer = self.get_serializer(document)
        return Response(serializer.data)


class ViolationTypeViewSet(viewsets.ModelViewSet):
    """API endpoint for violation types"""
    queryset = ViolationType.objects.all()
    serializer_class = ViolationTypeSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'code', 'description']
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsOfficerOrAdmin()]
        return [permissions.IsAuthenticated()]


class NotificationViewSet(viewsets.ModelViewSet):
    """ViewSet for managing notifications."""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Return notifications for the current user."""
        return Notification.objects.filter(user=self.request.user).order_by('-created_at')

    @action(detail=True, methods=['post'])
    def mark_as_read(self, request, pk=None):
        """Mark a notification as read."""
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'notification marked as read'})

    @action(detail=False, methods=['post'])
    def mark_all_as_read(self, request):
        """Mark all notifications as read."""
        self.get_queryset().update(is_read=True)
        return Response({'status': 'all notifications marked as read'})


class ViolationViewSet(viewsets.ModelViewSet):
    """API endpoint for violations"""
    queryset = Violation.objects.all()
    serializer_class = ViolationSerializer
    permission_classes = [IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.is_admin():
            return Violation.objects.all()
        elif user.is_officer():
            return Violation.objects.all()
        
        # For vehicle owners, filter by their vehicles
        try:
            vehicle_owner = user.vehicle_owner
            return Violation.objects.filter(vehicle__owner=vehicle_owner)
        except AttributeError:
            # If user doesn't have a vehicle_owner relationship
            return Violation.objects.none()
    
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """Get violation statistics"""
        period = request.query_params.get('period', 'all')
        user = request.user
        
        # Base queryset
        queryset = self.get_queryset()
        
        # Filter by date range
        now = timezone.now()
        if period == 'today':
            queryset = queryset.filter(created_at__date=now.date())
        elif period == 'week':
            queryset = queryset.filter(created_at__gte=now - timedelta(days=7))
        elif period == 'month':
            queryset = queryset.filter(created_at__gte=now - timedelta(days=30))
        elif period == 'year':
            queryset = queryset.filter(created_at__gte=now - timedelta(days=365))
        
        # Calculate statistics
        total_count = queryset.count()
        pending_count = queryset.filter(status='pending').count()
        resolved_count = queryset.filter(status__in=['paid', 'appeal_approved']).count()
        total_fines = queryset.aggregate(total=Sum('fine_amount'))['total'] or 0
        
        # Get violation types breakdown
        type_stats = (
            queryset
            .values('violation_type__name')
            .annotate(count=Count('id'))
            .order_by('-count')
        )
        
        # Get monthly trend
        monthly_stats = (
            queryset
            .annotate(month=TruncMonth('created_at'))
            .values('month')
            .annotate(count=Count('id'))
            .order_by('month')
        )
        
        return Response({
            'total_violations': total_count,
            'pending_violations': pending_count,
            'resolved_violations': resolved_count,
            'total_fines': total_fines,
            'violation_types': type_stats,
            'monthly_trend': monthly_stats,
        })


class ViolationAppealViewSet(viewsets.ModelViewSet):
    """API endpoint for violation appeals"""
    queryset = ViolationAppeal.objects.all()
    serializer_class = ViolationAppealSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['violation', 'status', 'appealed_by']
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_admin:
            return ViolationAppeal.objects.all()
        elif user.is_officer:
            return ViolationAppeal.objects.all()
        return ViolationAppeal.objects.filter(appealed_by=user)
    
    def get_permissions(self):
        if self.action in ['review']:
            return [IsOfficerOrAdmin()]
        elif self.action == 'destroy':
            return [IsAdminUser()]
        return [permissions.IsAuthenticated()]
    
    def perform_create(self, serializer):
        serializer.save(appealed_by=self.request.user)
    
    @action(detail=True, methods=['post'], permission_classes=[IsOfficerOrAdmin])
    def review(self, request, pk=None):
        """Review an appeal (officer/admin only)"""
        appeal = self.get_object()
        status = request.data.get('status')
        notes = request.data.get('notes', '')
        
        if status not in ['approved', 'rejected']:
            return Response({'error': 'Status must be either approved or rejected'}, 
                           status=status.HTTP_400_BAD_REQUEST)
        
        appeal.status = status
        appeal.review_notes = notes
        appeal.reviewed_by = request.user
        appeal.review_date = timezone.now()
        appeal.save()
        
        # If appeal is approved, update violation status
        if status == 'approved':
            violation = appeal.violation
            violation.status = 'disputed'
            violation.save()
            
        serializer = self.get_serializer(appeal)
        return Response(serializer.data)


class PaymentViewSet(viewsets.ModelViewSet):
    """API endpoint for payments"""
    queryset = Payment.objects.all()
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['violation', 'status', 'payment_method', 'paid_by']
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_admin:
            return Payment.objects.all()
        elif user.is_officer:
            return Payment.objects.all()
        return Payment.objects.filter(paid_by=user)
    
    def get_permissions(self):
        if self.action == 'destroy':
            return [IsAdminUser()]
        return [permissions.IsAuthenticated()]
    
    @action(detail=False, methods=['get'])
    def my_payments(self, request):
        """Get payments made by the current user"""
        payments = Payment.objects.filter(paid_by=request.user)
        page = self.paginate_queryset(payments)
        
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(payments, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['post'])
    def create_checkout_session(self, request):
        """Create a Stripe checkout session for a violation payment"""
        violation_id = request.data.get('violation_id')
        
        if not violation_id:
            return Response({'error': 'Violation ID is required'}, 
                           status=status.HTTP_400_BAD_REQUEST)
        
        try:
            violation = Violation.objects.get(id=violation_id)
            
            # Check if user is authorized to pay this violation
            if not (request.user.is_admin or request.user.is_officer or 
                   request.user == violation.vehicle.owner):
                return Response({'error': 'You are not authorized to pay this violation'}, 
                               status=status.HTTP_403_FORBIDDEN)
            
            # Check if violation is already paid
            if violation.status == 'paid':
                return Response({'error': 'This violation has already been paid'}, 
                               status=status.HTTP_400_BAD_REQUEST)
                               
            # Create or get existing payment
            payment, created = Payment.objects.get_or_create(
                violation=violation,
                defaults={
                    'amount': violation.fine_amount,
                    'payment_method': 'stripe',
                    'status': 'pending',
                    'paid_by': request.user
                }
            )
            
            if not created:
                # Update existing payment if it failed before
                if payment.status == 'failed':
                    payment.status = 'pending'
                    payment.save()
                    
            # Create Stripe checkout session
            YOUR_DOMAIN = os.environ.get('SITE_DOMAIN')
            if not YOUR_DOMAIN:
                # Use request origin as fallback
                YOUR_DOMAIN = request.META.get('HTTP_ORIGIN', 'http://localhost:8000')
            
            checkout_session = stripe.checkout.Session.create(
                payment_method_types=['card'],
                line_items=[
                    {
                        'price_data': {
                            'currency': 'npr',
                            'product_data': {
                                'name': f'Violation Fine: {violation.violation_type.name}',
                                'description': f'License Plate: {violation.vehicle.license_plate}',
                            },
                            'unit_amount': int(float(violation.fine_amount) * 100),  # Convert to cents
                        },
                        'quantity': 1,
                    },
                ],
                mode='payment',
                success_url=f'{YOUR_DOMAIN}/payment/success?session_id={{CHECKOUT_SESSION_ID}}',
                cancel_url=f'{YOUR_DOMAIN}/payment/cancel',
                metadata={
                    'violation_id': str(violation.id),
                    'payment_id': str(payment.id),
                    'user_id': str(request.user.id)
                }
            )
            
            # Update payment with Stripe session ID
            payment.stripe_session_id = checkout_session.id
            payment.save()
            
            return Response({
                'id': checkout_session.id,
                'url': checkout_session.url
            })
                
        except Violation.DoesNotExist:
            return Response({'error': 'Violation not found'}, 
                           status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            logger.error(f"Stripe checkout error: {str(e)}")
            return Response({'error': str(e)}, 
                           status=status.HTTP_500_INTERNAL_SERVER_ERROR)


class LicensePlateDetectionViewSet(viewsets.ModelViewSet):
    """API endpoint for license plate detections"""
    queryset = LicensePlateDetection.objects.all()
    serializer_class = LicensePlateDetectionSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['user', 'detected_text', 'matched_vehicle']
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_admin:
            return LicensePlateDetection.objects.all()
        elif user.is_officer:
            return LicensePlateDetection.objects.all()
        return LicensePlateDetection.objects.filter(user=user)
    
    def perform_create(self, serializer):
        serializer.save(user=self.request.user)
    
    @action(detail=False, methods=['post'], parser_classes=[MultiPartParser, FormParser])
    def detect_plate(self, request):
        """Detect license plate in uploaded image"""
        if 'image' not in request.FILES:
            return Response({'error': 'Image file is required'}, 
                           status=status.HTTP_400_BAD_REQUEST)
        
        image_file = request.FILES['image']
        location_data = {
            'latitude': request.data.get('latitude'),
            'longitude': request.data.get('longitude'),
            'location_name': request.data.get('location_name')
        }
        
        try:
            # Save the uploaded image temporarily
            from django.core.files.storage import default_storage
            from django.core.files.base import ContentFile
            
            path = default_storage.save(f'temp/{image_file.name}', ContentFile(image_file.read()))
            temp_path = os.path.join(settings.MEDIA_ROOT, path)
            
            # Process the image with OCR
            plate_text, confidence, vehicle = detect_license_plate(
                temp_path, 
                user=request.user,
                save_detection=True,
                location_data=location_data
            )
            
            # Get the latest detection
            detection = LicensePlateDetection.objects.filter(user=request.user).latest('detected_at')
            serializer = self.get_serializer(detection)
            
            # Clean up the temporary file
            if os.path.exists(temp_path):
                os.remove(temp_path)
                
            return Response(serializer.data)
            
        except Exception as e:
            logger.error(f"License plate detection error: {str(e)}")
            return Response({'error': str(e)}, 
                           status=status.HTTP_500_INTERNAL_SERVER_ERROR)


# Authentication views
@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    """Register a new user"""
    try:
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            
            # Create token for the user
            token, _ = Token.objects.get_or_create(user=user)
            
            # Return user data and token
            return Response({
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'username': user.username,
                    'first_name': user.first_name,
                    'last_name': user.last_name,
                    'user_type': user.user_type,
                    'phone_number': user.phone_number
                },
                'token': token.key
            }, status=status.HTTP_201_CREATED)
        
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        # Log the error
        logger = logging.getLogger('django')
        logger.error(f"Registration error: {str(e)}")
        import traceback
        logger.error(traceback.format_exc())
        
        # Return error response
        return Response(
            {'error': f'Registration failed: {str(e)}'},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

@api_view(['POST'])
@permission_classes([AllowAny])
def login_user(request):
    """Login a user and return token"""
    data = request.data
    
    # Get username/email and password
    email_or_username = data.get('username') or data.get('email')
    password = data.get('password')
    
    if not email_or_username or not password:
        return Response(
            {'error': 'Both username/email and password are required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Check if user is trying to login with email
    user = None
    if '@' in email_or_username:
        try:
            user_obj = User.objects.get(email=email_or_username)
            # Try to authenticate with username
            user = authenticate(username=user_obj.username, password=password)
        except User.DoesNotExist:
            return Response(
                {'error': 'No user found with this email address'},
                status=status.HTTP_401_UNAUTHORIZED
            )
    else:
        # Try to authenticate with username directly
        user = authenticate(username=email_or_username, password=password)
    
    if user:
        # Get or create token
        token, _ = Token.objects.get_or_create(user=user)
        
        # Login user
        login(request, user)
        
        # Return user data and token
        return Response({
            'user': {
                'id': user.id,
                'email': user.email,
                'username': user.username,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'user_type': user.user_type,
                'phone_number': user.phone_number
            },
            'token': token.key
        })
    else:
        return Response(
            {'error': 'Invalid credentials'},
            status=status.HTTP_401_UNAUTHORIZED
        )

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_user(request):
    """Logout a user"""
    try:
        # Delete the user's token
        if hasattr(request.user, 'auth_token'):
            request.user.auth_token.delete()
        
        # Logout from session
        logout(request)
        return Response({'message': 'Successfully logged out'})
    except Exception as e:
        return Response({'error': str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    """Change user password"""
    user = request.user
    data = request.data
    
    current_password = data.get('current_password')
    new_password = data.get('new_password')
    
    if not current_password or not new_password:
        return Response(
            {'error': 'Both current and new password are required'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Check current password
    if not user.check_password(current_password):
        return Response(
            {'error': 'Current password is incorrect'},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Set new password
    user.set_password(new_password)
    user.save()
    
    return Response({'message': 'Password changed successfully'})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_profile(request):
    """Get user profile"""
    user = request.user
    
    return Response({
        'id': user.id,
        'email': user.email,
        'username': user.username,
        'full_name': user.get_full_name(),
        'first_name': user.first_name,
        'last_name': user.last_name,
        'user_type': user.user_type,
        'phone_number': user.phone_number,
        'address': user.address,
        'badge_number': user.badge_number,
        'profile_picture': request.build_absolute_uri(user.profile_picture.url) if user.profile_picture else None,
        'date_joined': user.date_joined
    })

@api_view(['PATCH'])
@permission_classes([IsAuthenticated])
def update_profile(request):
    """Update user profile"""
    user = request.user
    data = request.data
    
    # Update user fields if provided
    if 'first_name' in data:
        user.first_name = data['first_name']
    if 'last_name' in data:
        user.last_name = data['last_name']
    if 'phone_number' in data:
        user.phone_number = data['phone_number']
    if 'address' in data:
        user.address = data['address']
    
    # Save changes
    user.save()
    
    return Response({
        'id': user.id,
        'email': user.email,
        'username': user.username,
        'full_name': user.get_full_name(),
        'first_name': user.first_name,
        'last_name': user.last_name,
        'user_type': user.user_type,
        'phone_number': user.phone_number,
        'address': user.address,
        'badge_number': user.badge_number,
        'profile_picture': request.build_absolute_uri(user.profile_picture.url) if user.profile_picture else None,
        'date_joined': user.date_joined
    })