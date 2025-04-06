"""
URL Configuration for the API app.
"""
from django.urls import path, include

from cameras.urls import api_urlpatterns as cameras_api_urlpatterns

urlpatterns = [
    # API version 1 endpoints
    path('v1/', include([
        # Include cameras endpoints
        path('cameras/', include(cameras_api_urlpatterns)),
        
        # Include other API endpoints as needed
        # path('vehicles/', include('vehicles.api_urls')),
        # path('violations/', include('violations.api_urls')),
        # path('route-planner/', include('route_planner.api_urls')),
    ])),
]