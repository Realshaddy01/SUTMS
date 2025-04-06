"""
URL Configuration for SUTMS.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/4.2/topics/http/urls/
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.views.generic import RedirectView

urlpatterns = [
    # Admin
    path('admin/', admin.site.urls),
    
    # Authentication
    path('accounts/', include('allauth.urls')),
    
    # Core app (home page and health check)
    path('', include('core.urls')),
    
    # API endpoints
    path('api/', include('api.urls')),
    
    # OCR endpoints
    path('ocr/', include('ocr.urls')),
    
    # Favicon
    path('favicon.ico', RedirectView.as_view(url='/static/images/favicon.ico')),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)