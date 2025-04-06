"""
URL patterns for the OCR app.
"""
from django.urls import path
from django.http import JsonResponse

# Import views
from .api import (
    detect_license_plate,
    correct_detection_text,
    detection_list,
    detection_detail_api
)

# API health check endpoint
def ocr_api_health(request):
    return JsonResponse({
        "status": "ok",
        "message": "OCR API is operational"
    })

app_name = 'ocr'

urlpatterns = [
    # Health check endpoint
    path('health/', ocr_api_health, name='api_health'),
    
    # OCR API endpoints
    path('detect/', detect_license_plate, name='detect_license_plate'),
    path('detections/', detection_list, name='detection_list'),
    path('detections/<int:detection_id>/', detection_detail_api, name='detection_detail'),
    path('detections/<int:detection_id>/correct/', correct_detection_text, name='correct_detection_text'),
]