from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.utils import timezone
from django.shortcuts import get_object_or_404

from violations.models import Violation, ViolationType, ViolationAppeal, Notification
from vehicles.models import Vehicle
from api.serializers import (ViolationSerializer, ViolationTypeSerializer, 
                        ViolationAppealSerializer, NotificationSerializer)

class ViolationViewSet(viewsets.ModelViewSet):
    """ViewSet for managing traffic violations."""
    queryset = Violation.objects.all()
    serializer_class = ViolationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Filter violations based on user type."""
        user = self.request.user
        if user.is_staff:
            return Violation.objects.all()
        
        # For vehicle owners, filter by their vehicles
        try:
            vehicle_owner = user.vehicle_owner
            return Violation.objects.filter(vehicle__owner=vehicle_owner)
        except AttributeError:
            # If user doesn't have a vehicle_owner relationship
            return Violation.objects.none()

class ViolationTypeViewSet(viewsets.ModelViewSet):
    """ViewSet for managing violation types."""
    queryset = ViolationType.objects.all()
    serializer_class = ViolationTypeSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Return only active violation types for non-staff users."""
        if not self.request.user.is_staff:
            return ViolationType.objects.filter(is_active=True)
        return ViolationType.objects.all()

class ViolationAppealViewSet(viewsets.ModelViewSet):
    """ViewSet for managing violation appeals."""
    queryset = ViolationAppeal.objects.all()
    serializer_class = ViolationAppealSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Filter appeals based on user type."""
        user = self.request.user
        if user.is_staff:
            return ViolationAppeal.objects.all()
        return ViolationAppeal.objects.filter(appealed_by=user)

    def perform_create(self, serializer):
        """Set the appealed_by field to the current user."""
        serializer.save(appealed_by=self.request.user)

class NotificationViewSet(viewsets.ModelViewSet):
    """ViewSet for managing user notifications."""
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        """Return notifications for the current user."""
        return Notification.objects.filter(user=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_as_read(self, request, pk=None):
        """Mark a specific notification as read."""
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'notification marked as read'})

    @action(detail=False, methods=['post'])
    def mark_all_as_read(self, request):
        """Mark all notifications as read for the current user."""
        self.get_queryset().update(is_read=True)
        return Response({'status': 'all notifications marked as read'})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def report_violation(request):
    """
    Report a traffic violation.
    
    Request body should contain:
    - license_plate: The license plate of the vehicle
    - violation_type: ID of the violation type
    - description: Description of the violation
    - location: Location where the violation occurred
    - image: Optional image evidence
    """
    try:
        # Extract data from request
        license_plate = request.data.get('license_plate')
        violation_type_id = request.data.get('violation_type')
        description = request.data.get('description', '')
        location = request.data.get('location', '')
        
        # Validate required fields
        if not license_plate or not violation_type_id:
            return Response({
                'error': 'License plate and violation type are required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get violation type
        try:
            violation_type = ViolationType.objects.get(id=violation_type_id)
        except ViolationType.DoesNotExist:
            return Response({
                'error': 'Invalid violation type'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Get or create vehicle
        vehicle, created = Vehicle.objects.get_or_create(
            license_plate=license_plate,
            defaults={'vehicle_type': 'unknown'}
        )
        
        # Create violation
        violation = Violation.objects.create(
            vehicle=vehicle,
            violation_type=violation_type,
            description=description,
            location=location,
            reported_by=request.user,
            fine_amount=violation_type.base_fine
        )
        
        # Handle image upload if provided
        if 'image' in request.FILES:
            violation.evidence_image = request.FILES['image']
            violation.save()
        
        return Response({
            'id': violation.id,
            'message': 'Violation reported successfully'
        }, status=status.HTTP_201_CREATED)
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_violation_types(request):
    """
    Get a list of all violation types.
    """
    try:
        if request.user.is_staff:
            violation_types = ViolationType.objects.all()
        else:
            violation_types = ViolationType.objects.filter(is_active=True)
        
        serializer = ViolationTypeSerializer(violation_types, many=True)
        return Response(serializer.data)
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_vehicle_violations(request, vehicle_id):
    """
    Get violations for a specific vehicle.
    """
    try:
        # Get vehicle
        vehicle = get_object_or_404(Vehicle, id=vehicle_id)
        
        # Check permission
        if not request.user.is_staff and vehicle.owner != request.user:
            return Response({
                'error': 'You do not have permission to view this vehicle\'s violations'
            }, status=status.HTTP_403_FORBIDDEN)
        
        # Get violations
        violations = Violation.objects.filter(vehicle=vehicle)
        serializer = ViolationSerializer(violations, many=True)
        
        return Response(serializer.data)
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR) 