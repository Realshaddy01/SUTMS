"""
URL patterns for the cameras app.
"""

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from . import views

# API routes
router = DefaultRouter()
router.register(r'cameras', views.TrafficCameraViewSet)

api_urlpatterns = [
    path('', include(router.urls)),
    path('upload/', views.upload_camera_image, name='api_upload_camera_image'),
    path('simulate/', views.simulate_camera_capture, name='api_simulate_camera_capture'),
]

# Frontend routes
urlpatterns = [
    # Camera management views
    path('', views.camera_list, name='camera_list'),
    path('add/', views.camera_add, name='camera_add'),
    path('<int:pk>/', views.camera_detail, name='camera_detail'),
    path('<int:pk>/edit/', views.camera_edit, name='camera_edit'),
    path('<int:pk>/delete/', views.camera_delete, name='camera_delete'),
    
    # Camera capture views
    path('captures/', views.capture_list, name='capture_list'),
    path('captures/<int:pk>/', views.capture_detail, name='capture_detail'),
    path('<int:pk>/captures/', views.camera_captures, name='camera_captures'),
    
    # Simulation and demo views
    path('simulate/', views.run_camera_simulation, name='run_camera_simulation'),
    path('create-demo/', views.create_demo_cameras, name='create_demo_cameras'),
]