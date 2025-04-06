"""
App configuration for the OCR app.
"""
from django.apps import AppConfig


class OCRConfig(AppConfig):
    """Configuration for the OCR application."""
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'ocr'
    verbose_name = 'License Plate OCR'
    
    def ready(self):
        """Perform initialization when the app is ready."""
        # Import signals to register them
        import ocr.signals