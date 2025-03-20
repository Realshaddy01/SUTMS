from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import ViolationTypeViewSet, ViolationViewSet, ViolationAppealViewSet

router = DefaultRouter()
router.register(r'types', ViolationTypeViewSet, basename='violation-type')
router.register(r'', ViolationViewSet, basename='violation')
router.register(r'appeals', ViolationAppealViewSet, basename='violation-appeal')

urlpatterns = [
    path('', include(router.urls)),
]

