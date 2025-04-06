"""
URL patterns for the vehicles app.
"""
from django.urls import path

from . import views

app_name = 'vehicles'

urlpatterns = [
    # Web views
    path('', views.vehicle_list, name='list'),
    path('<int:vehicle_id>/', views.vehicle_detail, name='detail'),
    path('add/', views.add_vehicle, name='add'),
    path('<int:vehicle_id>/edit/', views.edit_vehicle, name='edit'),
    path('<int:vehicle_id>/documents/', views.vehicle_documents, name='documents'),
    path('<int:vehicle_id>/documents/add/', views.add_document, name='add_document'),
    path('qr-code/<int:vehicle_id>/', views.vehicle_qr_code, name='qr_code'),
    path('generate-qr-code/<int:vehicle_id>/', views.generate_qr_code, name='generate_qr_code'),
    path('scan-qr/', views.scan_qr, name='scan_qr'),
    
    # API endpoints
    path('api/search/', views.search_vehicle, name='api_search'),
    path('api/verify-qr/<str:code>/', views.verify_qr_code, name='api_verify_qr'),
]