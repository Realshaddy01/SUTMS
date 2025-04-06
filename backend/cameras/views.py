"""
Views for the cameras app.
"""

import os
import json
import time
import tempfile
import random
from datetime import datetime, timedelta

from django.conf import settings
from django.shortcuts import render, redirect, get_object_or_404
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.core.paginator import Paginator
from django.urls import reverse
from django.db.models import Count, Avg, Max, Min

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import api_view, permission_classes, action
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser

from .models import TrafficCamera, CameraCapture, CameraStatus
from .serializers import TrafficCameraSerializer, CameraCaptureSerializer
from .forms import TrafficCameraForm

# Import the traffic camera integration module
import sys
import cv2
import numpy as np
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))
from optimized_ocr import ocr_license_plate

class TrafficCameraViewSet(viewsets.ModelViewSet):
    """
    API endpoint for managing traffic cameras.
    """
    queryset = TrafficCamera.objects.all()
    serializer_class = TrafficCameraSerializer
    permission_classes = [permissions.IsAuthenticated]
    
    @action(detail=True, methods=['post'])
    def capture(self, request, pk=None):
        """
        Trigger a camera to capture an image.
        """
        camera = self.get_object()
        
        # In a real implementation, we would connect to the camera
        # and capture a frame. For demonstration, we'll create a dummy image.
        
        # Update camera status
        camera.status = CameraStatus.ONLINE
        camera.last_capture_time = timezone.now()
        camera.save()
        
        # Simulate a capture
        response = {
            'success': True,
            'camera_id': camera.camera_id,
            'timestamp': camera.last_capture_time.isoformat(),
            'message': 'Capture initiated'
        }
        
        return Response(response)
    
    @action(detail=True, methods=['get'])
    def status(self, request, pk=None):
        """
        Get the current status of a camera.
        """
        camera = self.get_object()
        
        response = {
            'camera_id': camera.camera_id,
            'name': camera.name,
            'status': camera.status,
            'is_active': camera.is_active,
            'last_capture_time': camera.last_capture_time.isoformat() if camera.last_capture_time else None,
            'error_message': camera.error_message
        }
        
        return Response(response)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
@csrf_exempt
def upload_camera_image(request):
    """
    Handle upload of an image from a traffic camera and process it for license plate detection.
    
    Expected parameters:
    - camera_id: ID of the camera that captured the image
    - image: The uploaded image file
    """
    camera_id = request.data.get('camera_id')
    image_file = request.FILES.get('image')
    
    if not camera_id or not image_file:
        return Response({
            'success': False,
            'error': 'Missing camera_id or image'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        # Get or create the camera
        camera, created = TrafficCamera.objects.get_or_create(
            camera_id=camera_id,
            defaults={
                'name': f'Camera {camera_id}',
                'location': 'Unknown Location',
                'status': CameraStatus.ONLINE
            }
        )
        
        # Update camera status
        camera.status = CameraStatus.ONLINE
        camera.last_capture_time = timezone.now()
        camera.save()
        
        # Save the uploaded image as a CameraCapture
        capture = CameraCapture(camera=camera)
        capture.image.save(
            f'{camera_id}_{int(time.time())}.jpg',
            image_file
        )
        
        # Process the image for license plate detection
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as temp_file:
            temp_path = temp_file.name
            for chunk in image_file.chunks():
                temp_file.write(chunk)
        
        try:
            # Run license plate detection
            start_time = time.time()
            result = ocr_license_plate(temp_path)
            detection_time = time.time() - start_time
            
            # Update the capture with the results
            capture.processed = True
            capture.detection_time = detection_time
            
            if result['success']:
                capture.plate_detected = True
                capture.detected_plate_text = result.get('processed_text', '')
                capture.confidence = result.get('confidence', 0.0)
            
            capture.save()
            
            # Clean up the temp file
            os.unlink(temp_path)
            
            return Response({
                'success': True,
                'camera_id': camera.camera_id,
                'capture_id': capture.id,
                'timestamp': capture.timestamp.isoformat(),
                'plate_detected': capture.plate_detected,
                'detected_plate_text': capture.detected_plate_text,
                'confidence': capture.confidence,
                'detection_time': capture.detection_time
            })
        
        except Exception as e:
            # Clean up the temp file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            
            return Response({
                'success': False,
                'error': str(e)
            }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def simulate_camera_capture(request):
    """
    Simulate a camera capture for testing purposes.
    """
    camera_id = request.data.get('camera_id')
    
    if not camera_id:
        return Response({
            'success': False,
            'error': 'Missing camera_id'
        }, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        # Get or create the camera
        camera, created = TrafficCamera.objects.get_or_create(
            camera_id=camera_id,
            defaults={
                'name': f'Simulated Camera {camera_id}',
                'location': 'Simulated Location',
                'status': CameraStatus.ONLINE
            }
        )
        
        # Use a test image as a simulated capture
        test_image_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
            'new_improved_test_plate.jpg'
        )
        
        if not os.path.exists(test_image_path):
            # Fall back to another test image
            test_image_path = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
                'test_plate.jpg'
            )
            
            if not os.path.exists(test_image_path):
                return Response({
                    'success': False,
                    'error': 'Test image not found'
                }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
        # Create a new capture
        capture = CameraCapture(camera=camera)
        
        # Save the test image as the capture image
        with open(test_image_path, 'rb') as f:
            capture.image.save(
                f'simulated_{camera_id}_{int(time.time())}.jpg',
                ContentFile(f.read())
            )
        
        # Process the image for license plate detection
        start_time = time.time()
        result = ocr_license_plate(test_image_path)
        detection_time = time.time() - start_time
        
        # Update the capture with the results
        capture.processed = True
        capture.detection_time = detection_time
        
        if result['success']:
            capture.plate_detected = True
            capture.detected_plate_text = result.get('processed_text', '')
            capture.confidence = result.get('confidence', 0.0)
        
        capture.save()
        
        # Update camera status
        camera.status = CameraStatus.ONLINE
        camera.last_capture_time = timezone.now()
        camera.save()
        
        return Response({
            'success': True,
            'camera_id': camera.camera_id,
            'capture_id': capture.id,
            'timestamp': capture.timestamp.isoformat(),
            'plate_detected': capture.plate_detected,
            'detected_plate_text': capture.detected_plate_text,
            'confidence': capture.confidence,
            'detection_time': capture.detection_time,
            'message': 'Simulated capture processed successfully'
        })
    
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        
# Frontend views

@login_required
def camera_list(request):
    """View for listing all cameras."""
    cameras = TrafficCamera.objects.all().order_by('-last_capture_time')
    
    # Get recent captures
    recent_captures = CameraCapture.objects.all().order_by('-timestamp')[:6]
    
    # Stats
    total_cameras = cameras.count()
    online_cameras = cameras.filter(status=CameraStatus.ONLINE).count()
    total_captures = CameraCapture.objects.count()
    detection_success_rate = CameraCapture.objects.filter(plate_detected=True).count() / total_captures * 100 if total_captures > 0 else 0
    
    context = {
        'cameras': cameras,
        'recent_captures': recent_captures,
        'total_cameras': total_cameras,
        'online_cameras': online_cameras,
        'offline_cameras': total_cameras - online_cameras,
        'total_captures': total_captures,
        'detection_success_rate': round(detection_success_rate, 1),
    }
    
    return render(request, 'cameras/index.html', context)

@login_required
def camera_add(request):
    """View for adding a new camera."""
    if request.method == 'POST':
        form = TrafficCameraForm(request.POST)
        if form.is_valid():
            camera = form.save(commit=False)
            camera.save()
            messages.success(request, f'Camera {camera.name} created successfully!')
            return redirect('camera_list')
    else:
        form = TrafficCameraForm()
    
    return render(request, 'cameras/camera_form.html', {'form': form, 'title': 'Add New Camera'})

@login_required
def camera_detail(request, pk):
    """View for a camera's details."""
    camera = get_object_or_404(TrafficCamera, pk=pk)
    captures = CameraCapture.objects.filter(camera=camera).order_by('-timestamp')[:10]
    
    # Camera stats
    capture_count = CameraCapture.objects.filter(camera=camera).count()
    detection_success = CameraCapture.objects.filter(camera=camera, plate_detected=True).count()
    success_rate = (detection_success / capture_count * 100) if capture_count > 0 else 0
    avg_confidence = CameraCapture.objects.filter(camera=camera, plate_detected=True).aggregate(Avg('confidence'))['confidence__avg'] or 0
    
    context = {
        'camera': camera,
        'captures': captures,
        'capture_count': capture_count,
        'detection_success': detection_success,
        'success_rate': round(success_rate, 1),
        'avg_confidence': round(avg_confidence * 100, 1),
    }
    
    return render(request, 'cameras/camera_detail.html', context)

@login_required
def camera_edit(request, pk):
    """View for editing a camera."""
    camera = get_object_or_404(TrafficCamera, pk=pk)
    
    if request.method == 'POST':
        form = TrafficCameraForm(request.POST, instance=camera)
        if form.is_valid():
            form.save()
            messages.success(request, f'Camera {camera.name} updated successfully!')
            return redirect('camera_detail', pk=camera.pk)
    else:
        form = TrafficCameraForm(instance=camera)
    
    return render(request, 'cameras/camera_form.html', {'form': form, 'title': 'Edit Camera', 'camera': camera})

@login_required
def camera_delete(request, pk):
    """View for deleting a camera."""
    camera = get_object_or_404(TrafficCamera, pk=pk)
    
    if request.method == 'POST':
        camera_name = camera.name
        camera.delete()
        messages.success(request, f'Camera {camera_name} deleted successfully!')
        return redirect('camera_list')
    
    return render(request, 'cameras/camera_confirm_delete.html', {'camera': camera})

@login_required
def capture_list(request):
    """View for listing all captures."""
    captures = CameraCapture.objects.all().order_by('-timestamp')
    
    # Pagination
    paginator = Paginator(captures, 20)  # Show 20 captures per page
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    return render(request, 'cameras/capture_list.html', {'page_obj': page_obj})

@login_required
def capture_detail(request, pk):
    """View for a capture's details."""
    capture = get_object_or_404(CameraCapture, pk=pk)
    return render(request, 'cameras/capture_detail.html', {'capture': capture})

@login_required
def camera_captures(request, pk):
    """View for listing a camera's captures."""
    camera = get_object_or_404(TrafficCamera, pk=pk)
    captures = CameraCapture.objects.filter(camera=camera).order_by('-timestamp')
    
    # Pagination
    paginator = Paginator(captures, 20)  # Show 20 captures per page
    page_number = request.GET.get('page')
    page_obj = paginator.get_page(page_number)
    
    return render(request, 'cameras/camera_captures.html', {
        'camera': camera,
        'page_obj': page_obj
    })

@login_required
def run_camera_simulation(request):
    """View to run a camera simulation."""
    if request.method == 'POST':
        camera_id = request.POST.get('camera_id', f'SIM{random.randint(1, 999):03d}')
        
        # Call the simulate_camera_capture view
        response_data = simulate_camera_capture(request._request)
        
        if response_data.status_code == 200:
            messages.success(request, 'Camera simulation run successfully!')
        else:
            messages.error(request, f'Error running camera simulation: {response_data.data.get("error", "Unknown error")}')
        
        return redirect('camera_list')
    
    # Get all cameras for the form
    cameras = TrafficCamera.objects.all()
    
    return render(request, 'cameras/simulation_form.html', {'cameras': cameras})

@login_required
def create_demo_cameras(request):
    """View to create demo cameras."""
    if request.method == 'POST':
        try:
            # Create a set of demo cameras
            locations = [
                ('Kathmandu City Center', 27.7172, 85.3240),
                ('Pokhara Lake Side', 28.2096, 83.9856),
                ('Bhaktapur Durbar Square', 27.6710, 85.4298),
                ('Biratnagar Main Road', 26.4505, 87.2701),
                ('Nepalgunj Highway', 28.0500, 81.6167),
            ]
            
            cameras_created = 0
            
            for i, (location, lat, lng) in enumerate(locations):
                camera_id = f'CAM{i+1:03d}'
                camera, created = TrafficCamera.objects.get_or_create(
                    camera_id=camera_id,
                    defaults={
                        'name': f'Demo Camera {i+1}',
                        'location': location,
                        'description': f'Automatically created demo camera at {location}',
                        'status': CameraStatus.ONLINE,
                        'coordinates_lat': lat,
                        'coordinates_lng': lng,
                    }
                )
                
                if created:
                    cameras_created += 1
            
            messages.success(request, f'Created {cameras_created} demo cameras successfully!')
        except Exception as e:
            messages.error(request, f'Error creating demo cameras: {str(e)}')
        
        return redirect('camera_list')
    
    return render(request, 'cameras/create_demo_confirm.html')