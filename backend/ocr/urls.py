"""
URL patterns for the OCR app.
"""
from django.urls import path

from . import views, api

app_name = 'ocr'

urlpatterns = [
    # Web views
    path('', views.ocr_dashboard, name='dashboard'),
    path('test/', views.ocr_test, name='test'),
    path('detections/', views.detection_list, name='detections'),
    path('detections/<int:detection_id>/', views.detection_detail, name='detection_detail'),
    
    # API endpoints
    path('api/detect/', api.detect_license_plate, name='api_detect'),
    path('api/detect-text/', api.detect_license_plate_text, name='api_detect_text'),
    path('api/detections/', api.detection_list, name='api_detections'),
    path('api/detections/<int:detection_id>/', api.detection_detail, name='api_detection_detail'),
]