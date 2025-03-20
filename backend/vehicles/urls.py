from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import VehicleViewSet, VehicleDocumentViewSet

router = DefaultRouter()
router.register(r'', VehicleViewSet, basename='vehicle')
router.register(r'documents', VehicleDocumentViewSet, basename='vehicle-document')

urlpatterns = [
    path('', include(router.urls)),
]

