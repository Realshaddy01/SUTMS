"""
URL Configuration for SUTMS Project
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static
from django.conf.urls.i18n import i18n_patterns
from django.views.i18n import set_language
from core.views import home_view
from rest_framework import permissions
from drf_yasg.views import get_schema_view
from drf_yasg import openapi

# Create schema view for API documentation
schema_view = get_schema_view(
    openapi.Info(
        title="Smart Traffic Management API",
        default_version='v1',
        description="""
        API Documentation for Smart Traffic Management System
        
        Features:
        * License Plate Detection and Recognition
        * Vehicle Information Management
        * Traffic Violation Tracking
        """,
        terms_of_service="https://www.google.com/policies/terms/",
        contact=openapi.Contact(email="contact@smarttraffic.com"),
        license=openapi.License(name="BSD License"),
    ),
    public=True,
    permission_classes=(permissions.AllowAny,),
)

urlpatterns = [
    # Add homepage URL
    path('', home_view, name='home'),
    
    path('i18n/', include('django.conf.urls.i18n')),  # Add this for language switching
]

urlpatterns += i18n_patterns(
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path('ocr/', include('ocr.urls')),
    path('accounts/', include('accounts.urls')),
    path('cameras/', include('cameras.urls')),
    path('dashboard/', include('dashboard.urls')),
    path('payments/', include('payments.urls')),
    path('tracking/', include('tracking.urls')),
    path('vehicles/', include('vehicles.urls')),
    path('violations/', include('violations.urls')),
    path('route-planner/', include('route_planner.urls')),
    prefix_default_language=False
)

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# API Documentation URLs
urlpatterns += [
    path('api/docs/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('api/redoc/', schema_view.with_ui('redoc', cache_timeout=0), name='schema-redoc'),
]