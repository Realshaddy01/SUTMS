from django.urls import path, include
from rest_framework.routers import DefaultRouter
from authentication.views import UserRegistrationView, LoginView, LogoutView, UserProfileView, FCMTokenUpdateView
from vehicles.views import VehicleViewSet, VehicleDocumentViewSet
from violations.views import ViolationTypeViewSet, ViolationViewSet, ViolationAppealViewSet
from ocr.views import LicensePlateOCRView, QRCodeScanView
from dashboard.views import DashboardStatsView, OfficerStatsView, DriverStatsView
from payments.views import CreatePaymentIntentView, ConfirmPaymentView
from detection.views import DetectNumberPlateView, ProcessVideoView, ReportDetectionViolationView

router = DefaultRouter()
router.register(r'vehicles', VehicleViewSet, basename='vehicle')
router.register(r'vehicle-documents', VehicleDocumentViewSet, basename='vehicle-document')
router.register(r'violation-types', ViolationTypeViewSet, basename='violation-type')
router.register(r'violations', ViolationViewSet, basename='violation')
router.register(r'violation-appeals', ViolationAppealViewSet, basename='violation-appeal')

urlpatterns = [
  path('', include(router.urls)),
  
  # Authentication endpoints
  path('auth/', include('authentication.urls')),
  path('vehicles/', include('vehicles.urls')),
  path('violations/', include('violations.urls')),
  path('dashboard/', include('dashboard.urls')),
  path('ocr/', include('ocr.urls')),
  path('payments/', include('payments.urls')),
  path('detection/', include('detection.urls')),
]

