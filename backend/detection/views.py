from rest_framework import views, permissions, status
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from .models import DetectionModel, DetectionResult
from .utils import (
    detect_number_plate,
    detect_speed_violation,
    detect_signal_violation,
    detect_parking_violation,
    detect_over_capacity,
    detect_foreign_vehicle
)
from vehicles.models import Vehicle
from violations.models import Violation, ViolationType
from django.conf import settings
import os
import tempfile
import uuid

class DetectNumberPlateView(views.APIView):
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        if 'image' not in request.FILES:
            return Response({'error': 'No image provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        image_file = request.FILES['image']
        image_data = image_file.read()
        
        # Get active number plate detection model
        try:
            model = DetectionModel.objects.filter(
                model_type='number_plate',
                is_active=True
            ).latest('created_at')
        except DetectionModel.DoesNotExist:
            return Response({'error': 'No active number plate detection model found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Detect number plate
        detections = detect_number_plate(image_data, model.model_file.path)
        
        if not detections:
            return Response({'error': 'No number plate detected'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get best detection
        best_detection = max(detections, key=lambda x: x['confidence'])
        
        # Save detection result
        result = DetectionResult.objects.create(
            detection_model=model,
            image=image_file,
            number_plate=best_detection['plate_text'],
            confidence=best_detection['confidence'],
            metadata={
                'box': best_detection['box']
            }
        )
        
        # Try to find the vehicle in the database
        try:
            vehicle = Vehicle.objects.get(license_plate=best_detection['plate_text'])
            return Response({
                'detection_id': result.id,
                'number_plate': best_detection['plate_text'],
                'confidence': best_detection['confidence'],
                'vehicle_found': True,
                'vehicle_id': vehicle.id,
                'owner_name': f"{vehicle.owner.first_name} {vehicle.owner.last_name}",
                'vehicle_details': f"{vehicle.make} {vehicle.model} ({vehicle.color})"
            })
        except Vehicle.DoesNotExist:
            return Response({
                'detection_id': result.id,
                'number_plate': best_detection['plate_text'],
                'confidence': best_detection['confidence'],
                'vehicle_found': False
            })

class ProcessVideoView(views.APIView):
    parser_classes = (MultiPartParser, FormParser)
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        if 'video' not in request.FILES:
            return Response({'error': 'No video provided'}, status=status.HTTP_400_BAD_REQUEST)
        
        video_file = request.FILES['video']
        violation_types = request.data.getlist('violation_types', [])
        
        if not violation_types:
            violation_types = ['speed', 'signal', 'parking', 'capacity', 'foreign']
        
        # Save video to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.mp4') as temp_file:
            for chunk in video_file.chunks():
                temp_file.write(chunk)
            temp_file_path = temp_file.name
        
        try:
            results = []
            
            # Process video for each violation type
            for violation_type in violation_types:
                try:
                    model = DetectionModel.objects.filter(
                        model_type=violation_type,
                        is_active=True
                    ).latest('created_at')
                except DetectionModel.DoesNotExist:
                    continue
                
                # Detect violations
                if violation_type == 'speed':
                    violations = detect_speed_violation(temp_file_path, model.model_file.path)
                elif violation_type == 'signal':
                    violations = detect_signal_violation(temp_file_path, model.model_file.path)
                elif violation_type == 'parking':
                    violations = detect_parking_violation(temp_file_path, model.model_file.path)
                elif violation_type == 'capacity':
                    violations = detect_over_capacity(temp_file_path, model.model_file.path)
                elif violation_type == 'foreign':
                    violations = detect_foreign_vehicle(temp_file_path, model.model_file.path)
                else:
                    continue
                
                # Save detection results
                for violation in violations:
                    result = DetectionResult.objects.create(
                        detection_model=model,
                        video_timestamp=violation['timestamp'],
                        number_plate=violation['plate_text'],
                        confidence=violation['confidence'],
                        metadata={
                            'box': violation['box'],
                            'speed': violation.get('speed'),
                            'frame': violation['frame']
                        }
                    )
                    
                    results.append({
                        'detection_id': result.id,
                        'violation_type': violation_type,
                        'number_plate': violation['plate_text'],
                        'confidence': violation['confidence'],
                        'timestamp': violation['timestamp'],
                        'metadata': result.metadata
                    })
            
            return Response({
                'total_violations': len(results),
                'results': results
            })
        
        finally:
            # Clean up temporary file
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)

class ReportDetectionViolationView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        detection_id = request.data.get('detection_id')
        location = request.data.get('location')
        
        if not detection_id or not location:
            return Response({'error': 'detection_id and location are required'}, status=status.HTTP_400_BAD_REQUEST)
        
        try:
            detection = DetectionResult.objects.get(id=detection_id)
        except DetectionResult.DoesNotExist:
            return Response({'error': 'Detection not found'}, status=status.HTTP_404_NOT_FOUND)
        
        # Get or create vehicle
        vehicle = None
        if detection.number_plate:
            try:
                vehicle = Vehicle.objects.get(license_plate=detection.number_plate)
            except Vehicle.DoesNotExist:
                # Create temporary vehicle record
                vehicle = Vehicle.objects.create(
                    license_plate=detection.number_plate,
                    vehicle_type='unknown',
                    make='Unknown',
                    model='Unknown',
                    year=2023,
                    color='Unknown',
                    registration_number=f"TEMP-{uuid.uuid4().hex[:8].upper()}",
                    owner=None  # No owner for now
                )
        
        if not vehicle:
            return Response({'error': 'Could not identify vehicle'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Get violation type
        violation_type_name = detection.detection_model.get_model_type_display()
        violation_type, created = ViolationType.objects.get_or_create(
            name=violation_type_name,
            defaults={
                'description': f"Automated detection of {violation_type_name.lower()}",
                'fine_amount': 100.00,  # Default fine
                'penalty_points': 2     # Default penalty points
            }
        )
        
        # Create violation
        violation = Violation.objects.create(
            vehicle=vehicle,
            violation_type=violation_type,
            reported_by=request.user,
            location=location,
            description=f"Automated detection: {violation_type_name} detected with {detection.confidence*100:.1f}% confidence",
            evidence_image=detection.image,
            status='confirmed',
            fine_amount=violation_type.fine_amount
        )
        
        return Response({
            'success': True,
            'violation_id': violation.id,
            'message': f"{violation_type_name} violation reported successfully"
        })

