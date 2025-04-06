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
    path('add/', views.vehicle_add, name='add'),
    path('<int:vehicle_id>/edit/', views.vehicle_edit, name='edit'),
    path('qr-code/<int:vehicle_id>/', views.vehicle_qr_code, name='qr_code'),
    
    # API endpoints
    path('api/vehicles/', views.vehicle_list_api, name='api_list'),
    path('api/vehicles/<int:vehicle_id>/', views.vehicle_detail_api, name='api_detail'),
    path('api/verify-qr/<str:code>/', views.verify_qr_code, name='api_verify_qr'),
]