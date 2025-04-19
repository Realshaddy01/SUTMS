from django.urls import path, include
from django.contrib import admin
from api import views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('api.urls')),
    path('ocr/', include('ocr.urls')),  # Include OCR app URLs
    path('route-planner/', include('route_planner.urls')),  # Include Route Planner URLs
    path('api/detect-license-plate/', views.detect_license_plate, name='detect-license-plate'),
    path('api/lookup-vehicle/', views.lookup_vehicle_by_plate, name='lookup-vehicle'),
] 