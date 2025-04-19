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
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
import json
import tempfile
from django.http import JsonResponse

from accounts.models import UserProfile, User
from vehicles.models import Vehicle, VehicleDocument
from violations.models import Violation, ViolationType, ViolationAppeal, Notification
from payments.models import Payment, PaymentReceipt
from ocr.models import LicensePlateDetection, TrainingImage
from ocr.utils import detect_license_plate
from ocr.services import LicensePlateOCR
from ocr.license_plate_detector import NepaliLicensePlateProcessor

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
        
        if user.is_admin():
            return Vehicle.objects.all()
        elif user.is_officer():
            return Vehicle.objects.all()
        
        # For vehicle owners, filter by their VehicleOwner object
        try:
            vehicle_owner = user.vehicle_owner
            logger.info(f"Found vehicle owner: {vehicle_owner.id} for user {user.id}")
            return Vehicle.objects.filter(owner=vehicle_owner)
        except AttributeError as e:
            # If user doesn't have a vehicle_owner relationship
            logger.error(f"No vehicle_owner relationship for user {user.id}: {str(e)}")
            return Vehicle.objects.none()
        except Exception as e:
            logger.error(f"Error retrieving vehicles for user {user.id}: {str(e)}")
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
    filter_backends = [filters.SearchFilter]
    search_fields = ['name', 'code', 'description']
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsOfficerOrAdmin()]
        elif self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]


class NotificationViewSet(viewsets.ModelViewSet):
    """ViewSet for managing notifications."""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Return notifications for the current user."""
        user = self.request.user
        try:
            notifications = Notification.objects.filter(user=user).order_by('-created_at')
            logger.info(f"Found {notifications.count()} notifications for user {user.id}")
            return notifications
        except Exception as e:
            logger.error(f"Error retrieving notifications for user {user.id}: {str(e)}")
            return Notification.objects.none()

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
            fd, temp_path = tempfile.mkstemp(suffix='.jpg')
            os.close(fd)
            
            with open(temp_path, 'wb') as f:
                for chunk in image_file.chunks():
                    f.write(chunk)
            
            # Process the image with OCR
            ocr = LicensePlateOCR()
            license_number, confidence = ocr.extract_license_plate(temp_path, request.data.get('internet_available', 'true').lower() == 'true')
            
            if not license_number or confidence < 0.5:
                return Response({
                    'success': False,
                    'message': 'Failed to recognize license plate. Please try again.',
                    'confidence': confidence
                }, status=status.HTTP_400_BAD_REQUEST)
            
            # Get vehicle details
            try:
                vehicle = Vehicle.objects.get(license_plate=license_number)
                violations = Violation.objects.filter(vehicle=vehicle).order_by('-timestamp')[:3]
                
                # Check if vehicle is reported as stolen
                is_stolen = vehicle.status == 'stolen'
                
                return Response({
                    'success': True,
                    'license_plate': license_number,
                    'confidence': confidence,
                    'vehicle': {
                        'id': vehicle.id,
                        'make': vehicle.make,
                        'model': vehicle.model,
                        'year': vehicle.year,
                        'color': vehicle.color,
                        'owner_name': vehicle.owner.get_full_name(),
                        'tax_clearance': {
                            'is_cleared': vehicle.tax_clearance_status,
                            'expiry_date': vehicle.tax_expiry_date,
                        },
                        'is_stolen': is_stolen,
                        'total_violations': violations.count(),
                    },
                    'recent_violations': [
                        {
                            'id': v.id,
                            'violation_type': v.violation_type.name,
                            'location': v.location,
                            'timestamp': v.timestamp,
                            'fine_amount': v.fine_amount,
                            'status': v.status,
                        } for v in violations
                    ],
                })
                
            except Vehicle.DoesNotExist:
                return Response({
                    'success': True,
                    'license_plate': license_number,
                    'message': 'Vehicle not found in database',
                    'confidence': confidence
                })
            
        except Exception as e:
            logger.error(f"License plate detection error: {str(e)}")
            return Response({'error': str(e)}, 
                           status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)


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

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def report_violation(request):
    """
    API endpoint for reporting traffic violations.
    
    The endpoint accepts violation details and creates a new violation record.
    """
    # Validate required fields
    required_fields = ['vehicle_id', 'violation_type_id', 'location', 'description']
    for field in required_fields:
        if field not in request.data:
            return Response({'error': f'Missing required field: {field}'}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        # Get vehicle and violation type
        vehicle = get_object_or_404(Vehicle, id=request.data['vehicle_id'])
        violation_type = get_object_or_404(ViolationType, id=request.data['violation_type_id'])
        
        # Create new violation
        violation = Violation.objects.create(
            vehicle=vehicle,
            violation_type=violation_type,
            reported_by=request.user,
            location=request.data['location'],
            latitude=request.data.get('latitude'),
            longitude=request.data.get('longitude'),
            timestamp=timezone.now(),
            description=request.data['description'],
            fine_amount=violation_type.base_fine,
            status=Violation.Status.PENDING
        )
        
        # Handle evidence image if provided
        if 'evidence_image' in request.FILES:
            img = request.FILES['evidence_image']
            violation.evidence_image.save(f'evidence_{violation.id}.jpg', img)
        
        # Handle license plate image if provided
        if 'license_plate_image' in request.FILES:
            img = request.FILES['license_plate_image']
            violation.license_plate_image.save(f'plate_{violation.id}.jpg', img)
        
        # Create notification for vehicle owner
        Notification.objects.create(
            user=vehicle.owner,
            title=f'New Violation Reported',
            message=f'Your vehicle ({vehicle.license_plate}) has been reported for a {violation_type.name} violation.',
            notification_type='violation',
            related_violation=violation,
            link=f'/violations/{violation.id}'
        )
        
        return Response({
            'success': True,
            'message': 'Violation reported successfully',
            'violation_id': violation.id
        })
        
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Error reporting violation: {str(e)}'
        }, status=status.HTTP_400_BAD_REQUEST)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_violation_types(request):
    """Get list of violation types for dropdown selection."""
    try:
        violation_types = ViolationType.objects.filter(is_active=True)
        logger.info(f"Found {violation_types.count()} active violation types")
        return Response({
            'success': True,
            'violation_types': [
                {
                    'id': vt.id,
                    'name': vt.name,
                    'code': vt.code,
                    'description': vt.description,
                    'base_fine': vt.fine_amount,
                    'severity': getattr(vt, 'severity', 'medium')
                } for vt in violation_types
            ]
        })
    except Exception as e:
        logger.error(f"Error retrieving violation types: {str(e)}")
        return Response({
            'success': False,
            'message': f'Error retrieving violation types: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_vehicle_violations(request, vehicle_id):
    """Get violation history for a specific vehicle with date filtering."""
    try:
        vehicle = get_object_or_404(Vehicle, id=vehicle_id)
        
        # Get query parameters for date filtering
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        
        # Filter violations by date range if provided
        violations = Violation.objects.filter(vehicle=vehicle).order_by('-timestamp')
        if start_date:
            violations = violations.filter(timestamp__gte=start_date)
        if end_date:
            violations = violations.filter(timestamp__lte=end_date)
        
        return Response({
            'success': True,
            'vehicle': {
                'id': vehicle.id,
                'license_plate': vehicle.license_plate,
                'make': vehicle.make,
                'model': vehicle.model,
            },
            'violations': [
                {
                    'id': v.id,
                    'violation_type': v.violation_type.name,
                    'location': v.location,
                    'timestamp': v.timestamp,
                    'fine_amount': v.fine_amount,
                    'status': v.status,
                    'description': v.description,
                    'evidence_image': v.evidence_image.url if v.evidence_image else None,
                } for v in violations
            ],
            'total_count': violations.count()
        })
    
    except Exception as e:
        return Response({
            'success': False,
            'message': f'Error retrieving violations: {str(e)}'
        }, status=status.HTTP_400_BAD_REQUEST)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def detect_license_plate(request):
    """API endpoint for license plate detection"""
    if 'image' not in request.FILES:
        return Response({'error': 'No image provided'}, status=400)
    
    image = request.FILES['image']
    
    # Save the uploaded image temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix='.jpg') as tmp:
        tmp.write(image.read())
        tmp_path = tmp.name
    
    try:
        # Process the image
        processor = NepaliLicensePlateProcessor()
        results, annotated_image_path = processor.process_image(tmp_path)
        
        if not results:
            return Response({'error': 'No license plate detected'}, status=400)
        
        # Return the best result (highest confidence)
        best_result = max(results, key=lambda x: x['confidence'])
        
        # Get vehicle information if available
        from vehicles.models import Vehicle
        try:
            vehicle = Vehicle.objects.get(license_plate=best_result['text'])
            vehicle_info = {
                'id': vehicle.id,
                'license_plate': vehicle.license_plate,
                'make': vehicle.make,
                'model': vehicle.model,
                'owner_name': vehicle.owner_name,
                'year': vehicle.year,
                'color': vehicle.color,
                'registration_status': vehicle.is_registration_valid
            }
        except Vehicle.DoesNotExist:
            vehicle_info = None
        
        response = {
            'license_plate': best_result['text'],
            'confidence': float(best_result['confidence']),
            'vehicle_info': vehicle_info
        }
        
        return Response(response)
        
    except Exception as e:
        return Response({'error': str(e)}, status=500)
    finally:
        # Clean up temporary files
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        
        if 'annotated_image_path' in locals() and os.path.exists(annotated_image_path):
            os.unlink(annotated_image_path)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def lookup_vehicle_by_plate(request):
    try:
        license_plate = request.data.get('license_plate')
        if not license_plate:
            return JsonResponse({'error': 'License plate is required'}, status=400)
            
        try:
            vehicle = Vehicle.objects.get(license_plate__iexact=license_plate)
            
            # Get vehicle owner details
            owner_details = {
                'name': vehicle.owner.name,
                'email': vehicle.owner.email,
                'phone': vehicle.owner.phone
            }
            
            # Get recent violations
            recent_violations = []
            for violation in Violation.objects.filter(vehicle=vehicle).order_by('-created_at')[:5]:
                recent_violations.append({
                    'id': violation.id,
                    'type': violation.violation_type.name,
                    'date': violation.created_at.isoformat(),
                    'location': violation.location,
                    'fine_amount': float(violation.fine_amount),
                    'status': violation.status
                })
                
            return JsonResponse({
                'id': vehicle.id,
                'license_plate': vehicle.license_plate,
                'owner': owner_details,
                'make': vehicle.make,
                'model': vehicle.model,
                'year': vehicle.year,
                'color': vehicle.color,
                'registration_number': vehicle.registration_number,
                'registration_expiry': vehicle.registration_expiry.isoformat() if vehicle.registration_expiry else None,
                'is_insured': vehicle.is_insured,
                'insurance_provider': vehicle.insurance_provider,
                'insurance_expiry': vehicle.insurance_expiry.isoformat() if vehicle.insurance_expiry else None,
                'violations_count': Violation.objects.filter(vehicle=vehicle).count(),
                'recent_violations': recent_violations
            })
            
        except Vehicle.DoesNotExist:
            return JsonResponse({'error': 'Vehicle not found'}, status=404)
            
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)