"""
Signal handlers for the OCR application.
"""
import logging

from django.db.models.signals import post_save, post_delete
from django.dispatch import receiver

from .models import LicensePlateDetection, OCRModel

logger = logging.getLogger(__name__)


@receiver(post_save, sender=LicensePlateDetection)
def license_plate_detection_saved(sender, instance, created, **kwargs):
    """
    Handle post-save signal for LicensePlateDetection.
    
    This function is called when a LicensePlateDetection instance is saved.
    It can be used to trigger additional processing or notifications.
    
    Args:
        sender: The model class
        instance: The actual instance being saved
        created: Boolean; True if a new record was created
        **kwargs: Additional keyword arguments
    """
    if created:
        logger.info(
            "New license plate detection created: %s (ID: %s)",
            instance.display_text,
            instance.id
        )
        
        # Here you could add code to send notifications, update statistics, etc.
        # For example:
        # if instance.matched_vehicle:
        #     notify_vehicle_owner(instance)


@receiver(post_save, sender=OCRModel)
def ocr_model_saved(sender, instance, created, **kwargs):
    """
    Handle post-save signal for OCRModel.
    
    If a new active model is saved, deactivate other models of the same type.
    
    Args:
        sender: The model class
        instance: The actual instance being saved
        created: Boolean; True if a new record was created
        **kwargs: Additional keyword arguments
    """
    if instance.is_active:
        # Deactivate other models of the same type
        OCRModel.objects.filter(
            model_type=instance.model_type,
            is_active=True
        ).exclude(id=instance.id).update(is_active=False)
        
        logger.info(
            "Activated OCR model: %s (version: %s, type: %s)",
            instance.name,
            instance.version,
            instance.get_model_type_display()
        )