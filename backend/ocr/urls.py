from django.urls import path
from .views import LicensePlateOCRView, QRCodeScanView

urlpatterns = [
    path('license-plate/', LicensePlateOCRView.as_view(), name='license-plate-ocr'),
    path('qr-code/', QRCodeScanView.as_view(), name='qr-code-scan'),
]

