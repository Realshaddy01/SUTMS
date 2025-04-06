"""
Serializers for the cameras app.
"""

from rest_framework import serializers
from .models import TrafficCamera, CameraCapture

class TrafficCameraSerializer(serializers.ModelSerializer):
    """Serializer for the TrafficCamera model."""
    
    class Meta:
        model = TrafficCamera
        fields = [
            'id', 'camera_id', 'name', 'location', 'url', 'capture_interval',
            'latitude', 'longitude', 'status', 'is_active', 'last_capture_time',
            'error_message', 'created_at', 'updated_at'
        ]
        read_only_fields = ['status', 'last_capture_time', 'error_message', 'created_at', 'updated_at']

class CameraCaptureSerializer(serializers.ModelSerializer):
    """Serializer for the CameraCapture model."""
    camera_name = serializers.CharField(source='camera.name', read_only=True)
    
    class Meta:
        model = CameraCapture
        fields = [
            'id', 'camera', 'camera_name', 'image', 'timestamp', 'processed',
            'plate_detected', 'detected_plate_text', 'confidence', 'detection_time'
        ]
        read_only_fields = ['timestamp', 'processed', 'plate_detected', 'detected_plate_text', 'confidence', 'detection_time']