"""
URL patterns for the OCR app.
"""
from django.urls import path
from django.http import JsonResponse
from . import views
from . import api
from .views import LicensePlateDetectionView, VehicleInfoView

# Import views
from .api import (
    detect_license_plate,
    correct_detection_text,
    detection_list,
    detection_detail_api,
    lookup_vehicle_by_plate
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
    path('detect/', api.detect_license_plate, name='detect-license-plate'),
    path('detections/', detection_list, name='detection_list'),
    path('detections/<int:detection_id>/', detection_detail_api, name='detection_detail'),
    path('detections/<int:detection_id>/correct/', correct_detection_text, name='correct_detection_text'),
    path('lookup/', api.lookup_vehicle_by_plate, name='lookup-vehicle'),
    path('detect-plate/', LicensePlateDetectionView.as_view(), name='detect-plate'),
    path('vehicle-info/<str:license_plate>/', VehicleInfoView.as_view(), name='vehicle-info'),
]