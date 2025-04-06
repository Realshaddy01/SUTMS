"""
Models for the cameras app.
"""

from django.db import models
from django.utils.translation import gettext_lazy as _

class CameraStatus(models.TextChoices):
    """Status options for a traffic camera."""
    OFFLINE = 'offline', _('Offline')
    CONNECTING = 'connecting', _('Connecting')
    ONLINE = 'online', _('Online')
    ERROR = 'error', _('Error')

class TrafficCamera(models.Model):
    """Model representing a traffic camera in the system."""
    camera_id = models.CharField(_('camera ID'), max_length=50, unique=True)
    name = models.CharField(_('name'), max_length=100)
    location = models.CharField(_('location'), max_length=255)
    description = models.TextField(_('description'), blank=True, null=True)
    url = models.CharField(_('URL'), max_length=255, blank=True, null=True)
    capture_interval = models.IntegerField(_('capture interval (seconds)'), default=5)
    auth_token = models.CharField(_('authentication token'), max_length=255, blank=True, null=True)
    
    # Coordinates for map display
    coordinates_lat = models.FloatField(_('latitude'), default=0.0)
    coordinates_lng = models.FloatField(_('longitude'), default=0.0)
    
    # Legacy fields - these will be removed in a future migration
    latitude = models.FloatField(_('latitude (legacy)'), default=0.0)
    longitude = models.FloatField(_('longitude (legacy)'), default=0.0)
    
    status = models.CharField(
        _('status'),
        max_length=20,
        choices=CameraStatus.choices,
        default=CameraStatus.OFFLINE
    )
    is_active = models.BooleanField(_('is active'), default=True)
    last_capture_time = models.DateTimeField(_('last capture time'), null=True, blank=True)
    error_message = models.TextField(_('error message'), blank=True, null=True)
    created_at = models.DateTimeField(_('created at'), auto_now_add=True)
    updated_at = models.DateTimeField(_('updated at'), auto_now=True)

    class Meta:
        verbose_name = _('traffic camera')
        verbose_name_plural = _('traffic cameras')
        ordering = ['-last_capture_time', 'name']

    def __str__(self):
        """String representation of the camera."""
        return f"{self.name} ({self.camera_id})"

class CameraCapture(models.Model):
    """Model representing an image captured by a traffic camera."""
    camera = models.ForeignKey(
        TrafficCamera,
        on_delete=models.CASCADE,
        related_name='captures',
        verbose_name=_('camera')
    )
    image = models.ImageField(_('captured image'), upload_to='camera_captures/%Y/%m/%d/')
    timestamp = models.DateTimeField(_('timestamp'), auto_now_add=True)
    processed = models.BooleanField(_('processed'), default=False)
    plate_detected = models.BooleanField(_('plate detected'), default=False)
    detected_plate_text = models.CharField(_('detected plate text'), max_length=20, blank=True, null=True)
    confidence = models.FloatField(_('confidence'), default=0.0)
    detection_time = models.FloatField(_('detection time (seconds)'), default=0.0)
    
    class Meta:
        verbose_name = _('camera capture')
        verbose_name_plural = _('camera captures')
        ordering = ['-timestamp']

    def __str__(self):
        """String representation of the capture."""
        return f"Capture from {self.camera.name} at {self.timestamp}"