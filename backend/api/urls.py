"""
URL patterns for the API app.
"""
from django.urls import path, include

app_name = 'api'

urlpatterns = [
    # Include app-specific API URLs
    path('ocr/', include('ocr.urls')),
    path('tracking/', include('tracking.urls')),
    path('vehicles/', include('vehicles.urls')),
    path('violations/', include('violations.urls')),
    path('payments/', include('payments.urls')),
]