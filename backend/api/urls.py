"""
URL Configuration for the API app.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (ViolationViewSet, ViolationTypeViewSet, 
                   ViolationAppealViewSet, NotificationViewSet,
                   LicensePlateDetectionViewSet, report_violation, get_violation_types, get_vehicle_violations)

from cameras.urls import api_urlpatterns as cameras_api_urlpatterns
from api import views as api_views

# Create a router and register viewsets
router = DefaultRouter()
router.register(r'violations', ViolationViewSet)
router.register(r'violation-types', ViolationTypeViewSet)
router.register(r'violation-appeals', ViolationAppealViewSet)
router.register(r'notifications', NotificationViewSet, basename='notification')

urlpatterns = [
    # Authentication endpoints
    path('auth/register/', api_views.register_user, name='api_register'),
    path('auth/login/', api_views.login_user, name='api_login'),
    path('auth/logout/', api_views.logout_user, name='api_logout'),
    path('auth/change-password/', api_views.change_password, name='api_change_password'),
    
    # User profile endpoints
    path('users/profile/', api_views.get_profile, name='api_get_profile'),
    path('users/update_profile/', api_views.update_profile, name='api_update_profile'),
    
    # Include router URLs
    path('', include(router.urls)),
    
    # API version 1 endpoints
    path('v1/', include([
        # Include cameras endpoints
        path('cameras/', include(cameras_api_urlpatterns)),
        
        # Include other API endpoints as needed
        # path('vehicles/', include('vehicles.api_urls')),
        # path('violations/', include('violations.api_urls')),
        # path('route-planner/', include('route_planner.api_urls')),
    ])),
    path('scan-license-plate/', LicensePlateDetectionViewSet.as_view({'post': 'create'}), name='scan_license_plate'),
    path('report-violation/', report_violation, name='report_violation'),
    path('violation-types/', get_violation_types, name='violation_types'),
    path('vehicle/<int:vehicle_id>/violations/', get_vehicle_violations, name='vehicle_violations'),
]