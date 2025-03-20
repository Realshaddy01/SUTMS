from django.urls import path
from .views import DetectNumberPlateView, ProcessVideoView, ReportDetectionViolationView

urlpatterns = [
    path('number-plate/', DetectNumberPlateView.as_view(), name='detect-number-plate'),
    path('process-video/', ProcessVideoView.as_view(), name='process-video'),
    path('report-violation/', ReportDetectionViolationView.as_view(), name='report-detection-violation'),
]

