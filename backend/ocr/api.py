"""
API endpoints for the OCR application.
These endpoints provide the REST API interface for license plate detection.
"""
import logging
import os
import tempfile
from typing import Dict, Any

from django.conf import settings
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.db import transaction
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.http import JsonResponse
import cv2
import numpy as np

from .models import LicensePlateDetection
from .license_plate_detector import detector
from .nepali_ocr import ocr
from vehicles.models import Vehicle

# Configure logging
logger = logging.getLogger(__name__)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def detect_license_plate(request):
    """
    API endpoint for detecting license plates in an image.
    
    Args:
        request: HTTP request with image file
        
    Returns:
        JSON response with detection results
    """
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
            # Read the image
            image = cv2.imread(temp_path)
            if image is None:
                return JsonResponse({'error': 'Could not read image file'}, status=400)
            
            # Process the image
            result = detector.process_image(image)
            
            if not result['success']:
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


@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def correct_detection_text(request, detection_id):
    """
    API endpoint for correcting detected text.
    
    Args:
        request: HTTP request with corrected text
        detection_id: ID of the detection to correct
        
    Returns:
        JSON response with updated detection
    """
    try:
        # Get the detection
        try:
            detection = LicensePlateDetection.objects.get(id=detection_id)
        except LicensePlateDetection.DoesNotExist:
            return Response(
                {'error': 'Detection not found.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if user has permission
        if detection.user != request.user and not request.user.is_staff:
            return Response(
                {'error': 'You do not have permission to modify this detection.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Get corrected text from request
        try:
            data = request.data
            corrected_text = data.get('corrected_text', '').strip()
            
            if not corrected_text:
                return Response(
                    {'error': 'Corrected text cannot be empty.'},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except Exception as e:
            return Response(
                {'error': f'Invalid request data: {str(e)}'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Update the detection
        with transaction.atomic():
            detection.corrected_text = corrected_text
            detection.status = 'manual'
            detection.save(update_fields=['corrected_text', 'status'])
            
            # Try to match with vehicle
            vehicle = None
            try:
                vehicle = Vehicle.objects.filter(license_plate__iexact=corrected_text).first()
                if vehicle:
                    detection.matched_vehicle = vehicle
                    detection.save(update_fields=['matched_vehicle'])
            except Exception as e:
                logger.error("Error finding matching vehicle: %s", str(e))
        
        # Prepare response
        response_data = {
            'id': detection.id,
            'detected_text': detection.detected_text,
            'corrected_text': detection.corrected_text,
            'status': detection.status,
        }
        
        if detection.matched_vehicle:
            # Include basic vehicle information
            response_data['vehicle'] = {
                'id': detection.matched_vehicle.id,
                'license_plate': detection.matched_vehicle.license_plate,
                'make': detection.matched_vehicle.make,
                'model': detection.matched_vehicle.model,
                'color': detection.matched_vehicle.color,
                'year': detection.matched_vehicle.year,
                'owner_name': detection.matched_vehicle.owner.get_full_name(),
                'is_insured': not detection.matched_vehicle.is_insurance_expired,
                'registration_number': detection.matched_vehicle.registration_number
            }
        
        return Response(response_data, status=status.HTTP_200_OK)
    
    except Exception as e:
        logger.exception("Error correcting detection: %s", str(e))
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def detection_list(request):
    """
    API endpoint for listing license plate detections.
    
    Args:
        request: HTTP request
        
    Returns:
        JSON response with detection list
    """
    try:
        # Determine if admin should see all detections
        show_all = request.user.is_staff and request.query_params.get('show_all') == '1'
        
        if show_all:
            detections = LicensePlateDetection.objects.all().order_by('-created_at')
        else:
            detections = LicensePlateDetection.objects.filter(
                user=request.user
            ).order_by('-created_at')
        
        # Pagination
        from rest_framework.pagination import PageNumberPagination
        paginator = PageNumberPagination()
        paginator.page_size = 20
        result_page = paginator.paginate_queryset(detections, request)
        
        # Serialize detections
        detection_data = []
        for detection in result_page:
            data = {
                'id': detection.id,
                'detected_text': detection.detected_text,
                'corrected_text': detection.corrected_text,
                'confidence': detection.confidence,
                'status': detection.status,
                'created_at': detection.created_at,
                'processing_time_ms': detection.processing_time_ms,
                'is_in_training_set': detection.is_in_training_set,
            }
            
            if detection.original_image:
                data['original_image'] = request.build_absolute_uri(detection.original_image.url)
            
            if detection.cropped_plate:
                data['cropped_plate'] = request.build_absolute_uri(detection.cropped_plate.url)
            
            if detection.matched_vehicle:
                data['vehicle'] = {
                    'id': detection.matched_vehicle.id,
                    'license_plate': detection.matched_vehicle.license_plate,
                }
            
            detection_data.append(data)
        
        return paginator.get_paginated_response(detection_data)
    
    except Exception as e:
        logger.exception("Error listing detections: %s", str(e))
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def detection_detail_api(request, detection_id):
    """
    API endpoint for getting detection details.
    
    Args:
        request: HTTP request
        detection_id: ID of the detection to retrieve
        
    Returns:
        JSON response with detection details
    """
    try:
        # Get the detection
        try:
            detection = LicensePlateDetection.objects.get(id=detection_id)
        except LicensePlateDetection.DoesNotExist:
            return Response(
                {'error': 'Detection not found.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Check if user has permission
        if detection.user != request.user and not request.user.is_staff:
            return Response(
                {'error': 'You do not have permission to view this detection.'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Prepare response
        response_data = {
            'id': detection.id,
            'user': {
                'id': detection.user.id,
                'username': detection.user.username,
                'full_name': detection.user.get_full_name(),
            },
            'detected_text': detection.detected_text,
            'corrected_text': detection.corrected_text,
            'confidence': detection.confidence,
            'status': detection.status,
            'created_at': detection.created_at,
            'updated_at': detection.updated_at,
            'processing_time_ms': detection.processing_time_ms,
            'is_in_training_set': detection.is_in_training_set,
        }
        
        if detection.original_image:
            response_data['original_image'] = request.build_absolute_uri(detection.original_image.url)
        
        if detection.cropped_plate:
            response_data['cropped_plate'] = request.build_absolute_uri(detection.cropped_plate.url)
        
        if detection.matched_vehicle:
            response_data['vehicle'] = {
                'id': detection.matched_vehicle.id,
                'license_plate': detection.matched_vehicle.license_plate,
                'make': detection.matched_vehicle.make,
                'model': detection.matched_vehicle.model,
                'color': detection.matched_vehicle.color,
                'year': detection.matched_vehicle.year,
                'owner_name': detection.matched_vehicle.owner.get_full_name(),
                'is_insured': not detection.matched_vehicle.is_insurance_expired,
                'registration_number': detection.matched_vehicle.registration_number,
                'registration_expiry': detection.matched_vehicle.registration_expiry,
                'registration_expired': detection.matched_vehicle.is_registration_expired,
            }
        
        return Response(response_data, status=status.HTTP_200_OK)
    
    except Exception as e:
        logger.exception("Error getting detection details: %s", str(e))
        return Response(
            {'error': str(e)},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )