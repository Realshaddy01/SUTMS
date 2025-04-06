"""
URL patterns for the OCR app.
"""
from django.urls import path
from django.http import JsonResponse

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
]