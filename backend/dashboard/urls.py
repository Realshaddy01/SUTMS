from django.urls import path
from .views import DashboardStatsView, OfficerStatsView, DriverStatsView

urlpatterns = [
    path('stats/', DashboardStatsView.as_view(), name='dashboard-stats'),
    path('officer-stats/', OfficerStatsView.as_view(), name='officer-stats'),
    path('driver-stats/', DriverStatsView.as_view(), name='driver-stats'),
]

