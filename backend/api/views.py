import os
import stripe
import logging
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db.models import Q, Count, Sum
from django.shortcuts import get_object_or_404
from rest_framework import viewsets, permissions, status, filters
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from django_filters.rest_framework import DjangoFilterBackend

from accounts.models import UserProfile
from vehicles.models import Vehicle, VehicleDocument
from violations.models import Violation, ViolationType, ViolationAppeal
from payments.models import Payment, PaymentReceipt
from ocr.models import LicensePlateDetection, TrainingImage
from ocr.utils import detect_license_plate

from .serializers import (
    UserSerializer, UserProfileSerializer, VehicleSerializer, 
    VehicleDocumentSerializer, ViolationTypeSerializer, ViolationSerializer,
    ViolationAppealSerializer, PaymentSerializer, PaymentReceiptSerializer,
    LicensePlateDetectionSerializer, TrainingImageSerializer
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
    search_fields = ['email', 'full_name', 'username']
    filterset_fields = ['role', 'is_active']
    
    def get_queryset(self):
        # Regular users can only see their own profile
        # Officers and admins can see all profiles
        user = self.request.user
        if user.is_admin:
            return User.objects.all()
        elif user.is_officer:
            return User.objects.filter(Q(id=user.id) | Q(role='user'))
        return User.objects.filter(id=user.id)
    
    def get_permissions(self):
        if self.action in ['create', 'destroy']:
            return [permissions.IsAdminUser()]
        return super().get_permissions()
    
    @action(detail=False, methods=['get'])
    def me(self, request):
        """Get current user's profile"""
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)
    
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
        return Vehicle.objects.filter(owner=user)
    
    def perform_create(self, serializer):
        # Set owner to current user if not specified
        if 'owner' not in serializer.validated_data:
            serializer.save(owner=self.request.user)
        else:
            serializer.save()
    
    @action(detail=False, methods=['get'])
    def my_vehicles(self, request):
        """Get vehicles owned by the current user"""
        vehicles = Vehicle.objects.filter(owner=request.user)
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


class ViolationViewSet(viewsets.ModelViewSet):
    """API endpoint for violations"""
    queryset = Violation.objects.all()
    serializer_class = ViolationSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [filters.SearchFilter, DjangoFilterBackend]
    search_fields = ['vehicle__license_plate', 'location', 'description']
    filterset_fields = ['violation_type', 'vehicle', 'status', 'reported_by']
    
    def get_queryset(self):
        user = self.request.user
        
        if user.is_admin:
            return Violation.objects.all()
        elif user.is_officer:
            return Violation.objects.all()
        return Violation.objects.filter(vehicle__owner=user)
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update']:
            return [IsOfficerOrAdmin()]
        elif self.action == 'destroy':
            return [IsAdminUser()]
        return [permissions.IsAuthenticated()]
    
    def perform_create(self, serializer):
        serializer.save(reported_by=self.request.user)
    
    @action(detail=False, methods=['get'])
    def my_violations(self, request):
        """Get violations for vehicles owned by the current user"""
        violations = Violation.objects.filter(vehicle__owner=request.user)
        page = self.paginate_queryset(violations)
        
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(violations, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def reported_by_me(self, request):
        """Get violations reported by the current officer"""
        if not request.user.is_officer and not request.user.is_admin:
            return Response({'error': 'Only officers can access this endpoint'}, 
                           status=status.HTTP_403_FORBIDDEN)
                           
        violations = Violation.objects.filter(reported_by=request.user)
        page = self.paginate_queryset(violations)
        
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
            
        serializer = self.get_serializer(violations, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def stats(self, request):
        """Get violation statistics"""
        # Ensure user has appropriate permissions
        if not request.user.is_officer and not request.user.is_admin:
            # For regular users, only show their own stats
            violations = Violation.objects.filter(vehicle__owner=request.user)
        else:
            violations = Violation.objects.all()
            
        # Get counts by status
        status_counts = violations.values('status').annotate(count=Count('id'))
        
        # Get counts by violation type
        type_counts = violations.values('violation_type__name').annotate(count=Count('id'))
        
        # Get total fine amounts
        total_fines = violations.aggregate(total=Sum('fine_amount'))
        
        # Get counts by month (last 6 months)
        from django.utils import timezone
        from dateutil.relativedelta import relativedelta
        
        now = timezone.now()
        six_months_ago = now - relativedelta(months=6)
        
        monthly_counts = []
        for i in range(6):
            month_start = six_months_ago + relativedelta(months=i)
            month_end = month_start + relativedelta(months=1)
            
            count = violations.filter(timestamp__gte=month_start, timestamp__lt=month_end).count()
            monthly_counts.append({
                'month': month_start.strftime('%B'),
                'year': month_start.year,
                'count': count
            })
            
        return Response({
            'status_counts': status_counts,
            'type_counts': type_counts,
            'total_fines': total_fines,
            'monthly_counts': monthly_counts
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