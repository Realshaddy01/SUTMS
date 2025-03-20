from django.db import models
from django.conf import settings
import uuid
import os

def detection_model_path(instance, filename):
    ext = filename.split('.')[-1]
    filename = f"{uuid.uuid4()}.{ext}"
    return os.path.join('detection_models', filename)

class DetectionModel(models.Model):
    MODEL_TYPE_CHOICES = (
        ('number_plate', 'Number Plate Recognition'),
        ('speed', 'Speed Violation'),
        ('signal', 'Signal Violation'),
        ('parking', 'Parking Violation'),
        ('capacity', 'Over Capacity'),
        ('foreign', 'Foreign Vehicle'),
    )
    
    name = models.CharField(max_length=100)
    description = models.TextField()
    model_type = models.CharField(max_length=20, choices=MODEL_TYPE_CHOICES)
    model_file = models.FileField(upload_to=detection_model_path)
    version = models.CharField(max_length=20)
    accuracy = models.FloatField()
    created_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    
    def __str__(self):
        return f"{self.name} v{self.version}"

class DetectionResult(models.Model):
    detection_model = models.ForeignKey(DetectionModel, on_delete=models.CASCADE, related_name='results')
    image = models.ImageField(upload_to='detection_results', null=True, blank=True)
    video_timestamp = models.FloatField(null=True, blank=True)
    number_plate = models.CharField(max_length=20, null=True, blank=True)
    confidence = models.FloatField()
    metadata = models.JSONField(default=dict)
    created_at = models.DateTimeField(auto_now_add=True)
    
    def __str__(self):
        return f"Detection {self.id} - {self.number_plate or 'Unknown'}"

