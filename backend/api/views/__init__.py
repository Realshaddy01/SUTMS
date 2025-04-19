"""
API Views package for the SUTMS application.
This package contains view modules for the API endpoints.
"""

# Commented out because it depends on TrafficIncident that doesn't exist
# from .analytics_views import AnalyticsViewSet

# Import authentication views
from .auth_views import (
    register_user, login_user, logout_user, change_password,
    get_profile, update_profile
)

# Import violation views
from .violation_views import (
    ViolationViewSet,
    ViolationTypeViewSet,
    ViolationAppealViewSet,
    NotificationViewSet,
    report_violation,
    get_violation_types,
    get_vehicle_violations
)

# Import license plate detection views
from .license_plate_views import LicensePlateDetectionViewSet

# Export all views
__all__ = [
    'register_user', 'login_user', 'logout_user', 'change_password',
    'get_profile', 'update_profile', 'ViolationViewSet', 'ViolationTypeViewSet',
    'ViolationAppealViewSet', 'NotificationViewSet', 'LicensePlateDetectionViewSet',
    'report_violation', 'get_violation_types', 'get_vehicle_violations'
]