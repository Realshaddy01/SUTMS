"""
Models for the OCR (Optical Character Recognition) app.
This app handles license plate detection and text recognition.
"""
from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _


class LicensePlateDetection(models.Model):
    """Records of license plate detections."""
    class Status(models.TextChoices):
        SUCCESS = 'success', _('Success')
        FAILED = 'failed', _('Failed')
        MANUAL = 'manual', _('Manual Entry')
    
    class DetectionMethod(models.TextChoices):
        AUTOMATIC = 'automatic', _('Automatic')
        MANUAL = 'manual', _('Manual')
        API = 'api', _('API')
    
    # User who initiated the detection
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='license_plate_detections'
    )
    
    # Original and processed images
    original_image = models.ImageField(
        upload_to='detections/originals/',
        verbose_name=_('Original Image')
    )
    cropped_plate = models.ImageField(
        upload_to='detections/plates/',
        verbose_name=_('Cropped Plate'),
        null=True,
        blank=True
    )
    
    # Detection results
    detected_text = models.CharField(
        max_length=50,
        verbose_name=_('Detected Text'),
        blank=True
    )
    corrected_text = models.CharField(
        max_length=50,
        verbose_name=_('Corrected Text'),
        blank=True
    )
    confidence = models.FloatField(
        default=0,
        verbose_name=_('Confidence'),
        help_text=_('Confidence score of the detection (0-100)')
    )
    
    # Match to a vehicle if found
    matched_vehicle = models.ForeignKey(
        'vehicles.Vehicle',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='detections',
        verbose_name=_('Matched Vehicle')
    )
    
    # Location details
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    location_name = models.CharField(max_length=200, blank=True)
    
    # Processing details
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.FAILED,
        verbose_name=_('Status')
    )
    detection_method = models.CharField(
        max_length=20,
        choices=DetectionMethod.choices,
        default=DetectionMethod.AUTOMATIC,
        verbose_name=_('Detection Method')
    )
    processing_time_ms = models.IntegerField(
        default=0,
        verbose_name=_('Processing Time (ms)')
    )
    
    # Training flag
    is_in_training_set = models.BooleanField(
        default=False,
        verbose_name=_('Is in Training Set')
    )
    
    # Timestamps
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('License Plate Detection')
        verbose_name_plural = _('License Plate Detections')
        ordering = ['-created_at']
    
    def __str__(self):
        text = self.corrected_text or self.detected_text or 'Unknown'
        return f"Detection {self.id}: {text}"
    
    @property
    def display_text(self):
        """Return the corrected text if available, otherwise the detected text."""
        return self.corrected_text or self.detected_text or 'Unknown'
    
    @property
    def confidence_display(self):
        """Return the confidence as a formatted percentage."""
        return f"{self.confidence:.1f}%"


class OCRModel(models.Model):
    """
    OCR model versions and configurations.
    This model tracks different versions of the OCR models being used.
    """
    class ModelType(models.TextChoices):
        DETECTION = 'detection', _('License Plate Detection')
        RECOGNITION = 'recognition', _('Text Recognition')
        COMBINED = 'combined', _('Combined Detection and Recognition')
    
    name = models.CharField(max_length=100)
    version = models.CharField(max_length=20)
    model_type = models.CharField(
        max_length=20,
        choices=ModelType.choices,
        default=ModelType.COMBINED
    )
    
    description = models.TextField(blank=True)
    file_path = models.CharField(max_length=255)
    
    is_active = models.BooleanField(default=False)
    accuracy = models.FloatField(default=0)
    
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='created_models'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    last_used = models.DateTimeField(null=True, blank=True)
    
    class Meta:
        verbose_name = _('OCR Model')
        verbose_name_plural = _('OCR Models')
        ordering = ['-created_at']
        unique_together = ['name', 'version']
    
    def __str__(self):
        return f"{self.name} v{self.version} ({self.get_model_type_display()})"