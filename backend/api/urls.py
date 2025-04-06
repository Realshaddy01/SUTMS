"""
URL patterns for the API app.
"""
from django.urls import path, include
from django.http import JsonResponse

app_name = 'api'

# API Health Check endpoint
def api_health_check(request):
    return JsonResponse({
        "status": "ok",
        "message": "SUTMS API is operational",
        "version": "1.0.0"
    })

urlpatterns = [
    # Health check endpoint
    path('health/', api_health_check, name='api_health_check'),
    
    # Include app-specific API URLs
    path('ocr/', include('ocr.urls')),
]