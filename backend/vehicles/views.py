from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Vehicle, VehicleDocument
from .serializers import VehicleSerializer, VehicleDocumentSerializer
from django.shortcuts import get_object_or_404

class IsOwnerOrOfficer(permissions.BasePermission):
    def has_object_permission(self, request, view, obj):
        # Allow traffic officers and admins to view
        if request.user.user_type in ['officer', 'admin']:
            return True
        # Allow owners to view their own vehicles
        return obj.owner == request.user

class VehicleViewSet(viewsets.ModelViewSet):
    serializer_class = VehicleSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrOfficer]
    
    def get_queryset(self):
        user = self.request.user
        if user.user_type in ['officer', 'admin']:
            return Vehicle.objects.all()
        return Vehicle.objects.filter(owner=user)
    
    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)
    
    @action(detail=True, methods=['get'])
    def documents(self, request, pk=None):
        vehicle = self.get_object()
        documents = VehicleDocument.objects.filter(vehicle=vehicle)
        serializer = VehicleDocumentSerializer(documents, many=True)
        return Response(serializer.data)
    
    @action(detail=False, methods=['get'])
    def verify_by_plate(self, request):
        license_plate = request.query_params.get('license_plate', None)
        if not license_plate:
            return Response({'error': 'License plate is required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            vehicle = Vehicle.objects.get(license_plate=license_plate)
            serializer = self.get_serializer(vehicle)
            return Response(serializer.data)
        except Vehicle.DoesNotExist:
            return Response({'error': 'Vehicle not found'}, status=status.HTTP_404_NOT_FOUND)

class VehicleDocumentViewSet(viewsets.ModelViewSet):
    serializer_class = VehicleDocumentSerializer
    permission_classes = [permissions.IsAuthenticated, IsOwnerOrOfficer]
    
    def get_queryset(self):
        user = self.request.user
        if user.user_type in ['officer', 'admin']:
            return VehicleDocument.objects.all()
        return VehicleDocument.objects.filter(vehicle__owner=user)
    
    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        if request.user.user_type not in ['officer', 'admin']:
            return Response({'error': 'Not authorized'}, status=status.HTTP_403_FORBIDDEN)
        
        document = self.get_object()
        document.is_verified = True
        document.save()
        return Response({'status': 'Document verified'})

