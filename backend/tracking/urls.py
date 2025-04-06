"""
URL patterns for the tracking app.
"""
from django.urls import path

from . import views

app_name = 'tracking'

urlpatterns = [
    # Web views
    path('', views.tracking_dashboard, name='dashboard'),
    path('incidents/', views.incident_list, name='incident_list'),
    path('signals/', views.signal_list, name='signal_list'),
    
    # API endpoints
    path('api/location/', views.location_api, name='location_api'),
    path('api/incidents/', views.incident_api, name='incident_api'),
    path('api/signals/', views.signal_api, name='signal_api'),
]