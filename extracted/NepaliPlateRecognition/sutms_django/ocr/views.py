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

from .models import LicensePlateDetection, OCRModel
from .license_plate_detector import detector
from .nepali_ocr import ocr
from vehicles.models import Vehicle

# Configure logging
logger = logging.getLogger(__name__)


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