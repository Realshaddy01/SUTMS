from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from .models import ViolationType, Violation, ViolationAppeal
from .serializers import ViolationTypeSerializer, ViolationSerializer, ViolationAppealSerializer
from notifications.utils import send_notification

class IsOfficerOrAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user.user_type in ['officer', 'admin']

class ViolationTypeViewSet(viewsets.ModelViewSet):
    queryset = ViolationType.objects.all()
    serializer_class = ViolationTypeSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [permissions.IsAuthenticated(), IsOfficerOrAdmin()]
        return [permissions.IsAuthenticated()]

class ViolationViewSet(viewsets.ModelViewSet):
    serializer_class = ViolationSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.user_type in ['officer', 'admin']:
            return Violation.objects.all()
        # Drivers can only see violations for their vehicles
        return Violation.objects.filter(vehicle__owner=user)
    
    def get_permissions(self):
        if self.action in ['create']:
            return [permissions.IsAuthenticated(), IsOfficerOrAdmin()]
        return [permissions.IsAuthenticated()]
    
    def perform_create(self, serializer):
        violation = serializer.save()
        # Send notification to vehicle owner
        owner = violation.vehicle.owner
        if owner.fcm_token:
            title = "New Traffic Violation"
            body = f"A {violation.violation_type.name} violation has been reported for your vehicle {violation.vehicle.license_plate}."
            send_notification(owner.fcm_token, title, body, {
                'violation_id': violation.id,
                'type': 'new_violation'
            })
    
    @action(detail=True, methods=['post'])
    def confirm(self, request, pk=None):
        if request.user.user_type not in ['officer', 'admin']:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        violation = self.get_object()
        violation.status = 'confirmed'
        violation.save()
        
        # Send notification to vehicle owner
        owner = violation.vehicle.owner
        if owner.fcm_token:
            title = "Violation Confirmed"
            body = f"Your {violation.violation_type.name} violation has been confirmed. Fine amount: {violation.fine_amount}."
            send_notification(owner.fcm_token, title, body, {
                'violation_id': violation.id,
                'type': 'violation_confirmed'
            })
        
        return Response({'status': 'Violation confirmed'})
    
    @action(detail=True, methods=['post'])
    def pay(self, request, pk=None):
        violation = self.get_object()
        
        # Check if the user is the vehicle owner
        if request.user != violation.vehicle.owner:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        # Check if the violation is already paid
        if violation.is_paid:
            return Response({'error': 'Violation already paid'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Mark as paid
        violation.is_paid = True
        violation.payment_date = timezone.now()
        violation.status = 'resolved'
        violation.save()
        
        return Response({'status': 'Payment successful'})

class ViolationAppealViewSet(viewsets.ModelViewSet):
    serializer_class = ViolationAppealSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    def get_queryset(self):
        user = self.request.user
        if user.user_type in ['officer', 'admin']:
            return ViolationAppeal.objects.all()
        # Drivers can only see their own appeals
        return ViolationAppeal.objects.filter(submitted_by=user)
    
    @action(detail=True, methods=['post'])
    def review(self, request, pk=None):
        if request.user.user_type not in ['officer', 'admin']:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        appeal = self.get_object()
        status_decision = request.data.get('status')
        comments = request.data.get('comments', '')
        
        if status_decision not in ['approved', 'rejected']:
            return Response({'error': 'Invalid status'}, status=status.HTTP_400_BAD_REQUEST)
        
        appeal.status = status_decision
        appeal.reviewed_by = request.user
        appeal.reviewed_at = timezone.now()
        appeal.reviewer_comments = comments
        appeal.save()
        
        # Update the violation status based on the appeal decision
        violation = appeal.violation
        if status_decision == 'approved':
            violation.status = 'cancelled'
        else:
            violation.status = 'confirmed'
        violation.save()
        
        # Send notification to the appeal submitter
        submitter = appeal.submitted_by
        if submitter.fcm_token:
            title = "Appeal Decision"
            body = f"Your appeal for the {violation.violation_type.name} violation has been {status_decision}."
            send_notification(submitter.fcm_token, title, body, {
                'appeal_id': appeal.id,
                'violation_id': violation.id,
                'type': 'appeal_decision'
            })
        
        return Response({'status': f'Appeal {status_decision}'})

