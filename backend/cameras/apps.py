"""
App configuration for the cameras app.
"""

from django.apps import AppConfig
from django.utils.translation import gettext_lazy as _

class CamerasConfig(AppConfig):
    """Configuration for the cameras app."""
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'cameras'
    verbose_name = _('Traffic Cameras')

    def ready(self):
        """
        Initialize app when ready.
        This is a good place to set up signals or background tasks.
        """
        # Import signals handlers to register them
        try:
            import cameras.signals  # noqa: F401
        except ImportError:
            pass