"""
Views for the OCR application.
These views handle the web interface for license plate detection.
"""
import logging
import os
import tempfile
from pathlib import Path

from django.conf import settings
from django.shortcuts import render, redirect, get_object_or_404
from django.http import HttpResponse, JsonResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST, require_GET
from django.core.files.storage import default_storage
from django.contrib import messages
from django.utils.translation import gettext as _
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from django.core.files.base import ContentFile
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from drf_yasg.utils import swagger_auto_schema

from .models import LicensePlateDetection, OCRModel
from .license_plate_detector import NepaliLicensePlateDetector
from vehicles.models import Vehicle
from api.models import ViolationType, Violation
from .serializers import (
    LicensePlateDetectionSerializer,
    DetectionResponseSerializer,
    VehicleInfoSerializer
)

# Configure logging
logger = logging.getLogger(__name__)

# Initialize the detector
detector = NepaliLicensePlateDetector()

@login_required
def detect_license_plate(request):
    """
    View for license plate detection interface.
    
    Args:
        request: HTTP request
        
    Returns:
        Rendered template response
    """
    # Get recent detections for the current user
    recent_detections = LicensePlateDetection.objects.filter(
        user=request.user
    ).order_by('-created_at')[:5]
    
    context = {
        'recent_detections': recent_detections,
    }
    
    return render(request, 'ocr/detect_license_plate.html', context)


@login_required
def detection_detail(request, detection_id):
    """
    View for displaying detection details.
    
    Args:
        request: HTTP request
        detection_id: ID of the detection to display
        
    Returns:
        Rendered template response
    """
    detection = get_object_or_404(LicensePlateDetection, id=detection_id)
    
    # Check if the detection belongs to the current user or if user is staff
    if detection.user != request.user and not request.user.is_staff:
        messages.error(request, _("You don't have permission to view this detection."))
        return redirect('ocr:detect')
    
    # Try to find matching vehicle
    vehicle = None
    
    if detection.matched_vehicle:
        vehicle = detection.matched_vehicle
    else:
        # Try to find a vehicle with this license plate
        plate_text = detection.corrected_text or detection.detected_text
        if plate_text:
            try:
                vehicle = Vehicle.objects.filter(license_plate__iexact=plate_text).first()
                if vehicle:
                    # Update the detection with the matched vehicle
                    detection.matched_vehicle = vehicle
                    detection.save(update_fields=['matched_vehicle'])
            except Exception as e:
                logger.error("Error finding matching vehicle: %s", str(e))
    
    context = {
        'detection': detection,
        'vehicle': vehicle,
    }
    
    return render(request, 'ocr/detection_detail.html', context)


@login_required
@require_POST
def correct_detection(request, detection_id):
    """
    View for correcting detection text.
    
    Args:
        request: HTTP request
        detection_id: ID of the detection to correct
        
    Returns:
        JSON response
    """
    try:
        detection = get_object_or_404(LicensePlateDetection, id=detection_id)
        
        # Check if the detection belongs to the current user or if user is staff
        if detection.user != request.user and not request.user.is_staff:
            return JsonResponse({
                'status': 'error',
                'error': _("You don't have permission to modify this detection.")
            })
        
        # Get corrected text from request
        corrected_text = request.POST.get('corrected_text', '').strip()
        
        if not corrected_text:
            return JsonResponse({
                'status': 'error',
                'error': _("Corrected text cannot be empty.")
            })
        
        # Update the detection
        detection.corrected_text = corrected_text
        detection.status = 'manual'
        detection.save(update_fields=['corrected_text', 'status'])
        
        # Try to find matching vehicle
        vehicle = None
        try:
            vehicle = Vehicle.objects.filter(license_plate__iexact=corrected_text).first()
            if vehicle:
                detection.matched_vehicle = vehicle
                detection.save(update_fields=['matched_vehicle'])
        except Exception as e:
            logger.error("Error finding matching vehicle: %s", str(e))
        
        return JsonResponse({
            'status': 'success',
            'corrected_text': corrected_text,
            'vehicle': vehicle.id if vehicle else None
        })
    
    except Exception as e:
        logger.exception("Error correcting detection: %s", str(e))
        return JsonResponse({
            'status': 'error',
            'error': str(e)
        })


@login_required
@require_POST
def add_to_training(request, detection_id):
    """
    View for adding a detection to the training set.
    
    Args:
        request: HTTP request
        detection_id: ID of the detection to add to training
        
    Returns:
        JSON response
    """
    try:
        detection = get_object_or_404(LicensePlateDetection, id=detection_id)
        
        # Check if the detection belongs to the current user or if user is staff
        if detection.user != request.user and not request.user.is_staff:
            return JsonResponse({
                'status': 'error',
                'error': _("You don't have permission to modify this detection.")
            })
        
        # Get the text to use for training
        plate_text = detection.corrected_text or detection.detected_text
        
        if not plate_text:
            return JsonResponse({
                'status': 'error',
                'error': _("Detection has no text to use for training.")
            })
        
        # Mark as part of training set
        detection.is_in_training_set = True
        detection.save(update_fields=['is_in_training_set'])
        
        # Create a training image entry
        from training.models import TrainingImage
        
        training_image = TrainingImage(
            image=detection.original_image,
            license_plate_text=plate_text,
            added_by=request.user
        )
        training_image.save()
        
        return JsonResponse({
            'status': 'success',
            'message': _("Added to training set successfully.")
        })
    
    except Exception as e:
        logger.exception("Error adding to training set: %s", str(e))
        return JsonResponse({
            'status': 'error',
            'error': str(e)
        })


@login_required
@require_GET
def get_detection_status(request, detection_id):
    """
    View for getting detection status.
    
    Args:
        request: HTTP request
        detection_id: ID of the detection to get status for
        
    Returns:
        JSON response
    """
    try:
        detection = get_object_or_404(LicensePlateDetection, id=detection_id)
        
        # Check if the detection belongs to the current user or if user is staff
        if detection.user != request.user and not request.user.is_staff:
            return JsonResponse({
                'status': 'error',
                'error': _("You don't have permission to view this detection.")
            })
        
        # Return detection status
        return JsonResponse({
            'status': 'success',
            'detection_status': detection.status,
            'detected_text': detection.detected_text,
            'corrected_text': detection.corrected_text,
            'confidence': detection.confidence,
            'is_in_training_set': detection.is_in_training_set,
            'matched_vehicle': detection.matched_vehicle.id if detection.matched_vehicle else None
        })
    
    except Exception as e:
        logger.exception("Error getting detection status: %s", str(e))
        return JsonResponse({
            'status': 'error',
            'error': str(e)
        })


@login_required
def detection_history(request):
    """
    View for displaying detection history.
    
    Args:
        request: HTTP request
        
    Returns:
        Rendered template response
    """
    # Determine if we should show all detections or just the user's
    show_all = request.user.is_staff and request.GET.get('show_all') == '1'
    
    if show_all:
        detections = LicensePlateDetection.objects.all().order_by('-created_at')
    else:
        detections = LicensePlateDetection.objects.filter(
            user=request.user
        ).order_by('-created_at')
    
    # Pagination
    from django.core.paginator import Paginator
    paginator = Paginator(detections, 10)
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    context = {
        'page_obj': page_obj,
        'show_all': show_all,
    }
    
    return render(request, 'ocr/detection_history.html', context)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def detect_license_plate(request):
    try:
        if 'image' not in request.FILES:
            return JsonResponse({'error': 'No image file provided'}, status=400)
            
        image_file = request.FILES['image']
        
        # Save the uploaded image temporarily
        temp_path = default_storage.save(
            f'temp/plates/{image_file.name}',
            ContentFile(image_file.read())
        )
        
        try:
            # Detect and recognize the license plate
            result = detector.detect_and_recognize(temp_path)
            
            if 'error' in result:
                return JsonResponse({'error': result['error']}, status=400)
                
            # Get vehicle details if available
            license_plate = result['license_plate']
            try:
                vehicle = Vehicle.objects.get(license_plate=license_plate)
                result['vehicle'] = {
                    'id': vehicle.id,
                    'owner_name': vehicle.owner_name,
                    'make': vehicle.make,
                    'model': vehicle.model,
                    'year': vehicle.year,
                    'color': vehicle.color,
                    'registration_number': vehicle.registration_number,
                    'registration_expiry': vehicle.registration_expiry.isoformat() if vehicle.registration_expiry else None,
                    'violations_count': vehicle.violation_set.count(),
                    'is_reported_stolen': vehicle.is_reported_stolen,
                    'tax_clearance': vehicle.tax_clearance
                }
            except Vehicle.DoesNotExist:
                result['vehicle'] = None
                
            return JsonResponse(result)
            
        finally:
            # Clean up the temporary file
            if temp_path:
                default_storage.delete(temp_path)
                
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def lookup_vehicle_by_plate(request):
    try:
        license_plate = request.data.get('license_plate')
        if not license_plate:
            return JsonResponse({'error': 'License plate is required'}, status=400)
            
        try:
            vehicle = Vehicle.objects.get(license_plate=license_plate)
            
            # Get recent violations
            recent_violations = []
            for violation in vehicle.violation_set.all()[:5]:
                recent_violations.append({
                    'id': violation.id,
                    'type': violation.violation_type.name,
                    'date': violation.date.isoformat(),
                    'location': violation.location,
                    'fine_amount': float(violation.fine_amount),
                    'status': violation.status
                })
                
            return JsonResponse({
                'id': vehicle.id,
                'owner_name': vehicle.owner_name,
                'make': vehicle.make,
                'model': vehicle.model,
                'year': vehicle.year,
                'color': vehicle.color,
                'registration_number': vehicle.registration_number,
                'registration_expiry': vehicle.registration_expiry.isoformat() if vehicle.registration_expiry else None,
                'violations_count': vehicle.violation_set.count(),
                'recent_violations': recent_violations,
                'is_reported_stolen': vehicle.is_reported_stolen,
                'tax_clearance': vehicle.tax_clearance
            })
            
        except Vehicle.DoesNotExist:
            return JsonResponse({'error': 'Vehicle not found'}, status=404)
            
    except Exception as e:
        return JsonResponse({'error': str(e)}, status=500)

class LicensePlateDetectionView(APIView):
    """
    API endpoint for license plate detection and recognition
    """
    detector = NepaliLicensePlateDetector()

    @swagger_auto_schema(
        operation_summary="Detect License Plate",
        operation_description="""
        Upload an image to detect and recognize Nepali license plates.
        
        The API will:
        1. Detect the license plate in the image
        2. Recognize the text on the plate
        3. Return vehicle information if available
        
        The image should be clear and the license plate should be visible.
        """,
        request_body=LicensePlateDetectionSerializer,
        responses={
            200: DetectionResponseSerializer,
            400: "Bad Request - Invalid image format or no license plate detected",
            500: "Internal Server Error - Processing failed"
        },
        tags=['License Plate Detection']
    )
    def post(self, request):
        """Process image and detect license plate"""
        serializer = LicensePlateDetectionSerializer(data=request.data)
        if serializer.is_valid():
            try:
                image = request.FILES['image']
                # Detect license plate
                result = self.detector.detect_plate(image)
                if result['success']:
                    # Get vehicle info
                    vehicle_info = {
                        'license_plate': result['license_plate'],
                        'vehicle_type': 'Car',  # Example data
                        'owner_name': 'John Doe',  # Example data
                        'registration_date': '2023-01-01',  # Example data
                        'status': 'Active'  # Example data
                    }
                    response_data = {
                        'success': True,
                        'license_plate': result['license_plate'],
                        'confidence': result['confidence'],
                        'vehicle_info': vehicle_info,
                        'bbox': result['bbox']
                    }
                    return Response(response_data, status=status.HTTP_200_OK)
                return Response({
                    'success': False,
                    'error': 'No license plate detected'
                }, status=status.HTTP_400_BAD_REQUEST)
            except Exception as e:
                return Response({
                    'success': False,
                    'error': str(e)
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class VehicleInfoView(APIView):
    """
    API endpoint for retrieving vehicle information
    """
    
    @swagger_auto_schema(
        operation_summary="Get Vehicle Information",
        operation_description="Retrieve vehicle information by license plate number",
        responses={
            200: VehicleInfoSerializer,
            404: "Vehicle not found",
        },
        tags=['Vehicle Information']
    )
    def get(self, request, license_plate):
        """Get vehicle information by license plate"""
        # Example response
        vehicle_info = {
            'license_plate': license_plate,
            'vehicle_type': 'Car',
            'owner_name': 'John Doe',
            'registration_date': '2023-01-01',
            'status': 'Active'
        }
        return Response(vehicle_info, status=status.HTTP_200_OK)