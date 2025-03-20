from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.permissions import IsAuthenticated
from .utils import extract_license_plate, scan_qr_code
from vehicles.models import Vehicle
from django.contrib.auth import get_user_model

User = get_user_model()

class LicensePlateOCRView(APIView):
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        if 'image' not in request.FILES:
            return Response({'error': 'No image provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        image_file = request.FILES['image']
        image_data = image_file.read()
        
        license_plate = extract_license_plate(image_data)
        
        if not license_plate:
            return Response({'error': 'Could not extract license plate'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Try to find the vehicle in the database
        try:
            vehicle = Vehicle.objects.get(license_plate=license_plate)
            return Response({
                'license_plate': license_plate,
                'vehicle_found': True,
                'vehicle_id': vehicle.id,
                'owner_name': f"{vehicle.owner.first_name} {vehicle.owner.last_name}",
                'vehicle_details': f"{vehicle.make} {vehicle.model} ({vehicle.color})"
            })
        except Vehicle.DoesNotExist:
            return Response({
                'license_plate': license_plate,
                'vehicle_found': False
            })

class QRCodeScanView(APIView):
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [IsAuthenticated]
    
    def post(self, request):
        if 'image' not in request.FILES:
            return Response({'error': 'No image provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        image_file = request.FILES['image']
        image_data = image_file.read()
        
        qr_data = scan_qr_code(image_data)
        
        if not qr_data:
            return Response({'error': 'Could not scan QR code'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Parse QR data to identify if it's a user or vehicle
        if qr_data.startswith('SUTMS-USER-'):
            try:
                # Extract user ID from QR data
                user_id = qr_data.split('-')[2]
                user = User.objects.get(id=user_id)
                return Response({
                    'type': 'user',
                    'user_id': user.id,
                    'name': f"{user.first_name} {user.last_name}",
                    'user_type': user.user_type
                })
            except (IndexError, User.DoesNotExist):
                return Response({'error': 'Invalid user QR code'}, status=status.HTTP_400_BAD_REQUEST)
        
        elif qr_data.startswith('SUTMS-VEHICLE-'):
            try:
                # Extract vehicle ID from QR data
                vehicle_id = qr_data.split('-')[2]
                vehicle = Vehicle.objects.get(id=vehicle_id)
                return Response({
                    'type': 'vehicle',
                    'vehicle_id': vehicle.id,
                    'license_plate': vehicle.license_plate,
                    'owner_name': f"{vehicle.owner.first_name} {vehicle.owner.last_name}",
                    'vehicle_details': f"{vehicle.make} {vehicle.model} ({vehicle.color})"
                })
            except (IndexError, Vehicle.DoesNotExist):
                return Response({'error': 'Invalid vehicle QR code'}, status=status.HTTP_400_BAD_REQUEST)
        
        return Response({'error': 'Unknown QR code format'}, status=status.HTTP_400_BAD_REQUEST)

