"""
Models for the training app.
This app handles the management of data used for training the OCR models.
"""
from django.db import models
from django.conf import settings


class TrainingImage(models.Model):
    """Images used for training or fine-tuning the OCR models."""
    class DatasetType(models.TextChoices):
        TRAINING = 'training', 'Training'
        VALIDATION = 'validation', 'Validation'
        TEST = 'test', 'Test'
    
    image = models.ImageField(upload_to='training_images/')
    license_plate_text = models.CharField(max_length=20)
    bounding_box = models.CharField(max_length=100, blank=True)  # Format: "x,y,width,height"
    
    dataset_type = models.CharField(
        max_length=20,
        choices=DatasetType.choices,
        default=DatasetType.TRAINING
    )
    
    is_verified = models.BooleanField(default=False)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_training_images'
    )
    
    added_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='added_training_images'
    )
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Training Image'
        verbose_name_plural = 'Training Images'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Training Image {self.id} - {self.license_plate_text}"


class ModelTraining(models.Model):
    """Record of model training sessions."""
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        TRAINING = 'training', 'Training'
        COMPLETED = 'completed', 'Completed'
        FAILED = 'failed', 'Failed'
    
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    
    model_type = models.CharField(max_length=50)
    hyperparameters = models.JSONField(default=dict)
    
    training_images_count = models.IntegerField(default=0)
    validation_images_count = models.IntegerField(default=0)
    
    status = models.CharField(
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )
    
    initiated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='initiated_model_trainings'
    )
    
    started_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    
    accuracy = models.FloatField(null=True, blank=True)
    loss = models.FloatField(null=True, blank=True)
    
    model_file = models.FileField(upload_to='trained_models/', null=True, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = 'Model Training'
        verbose_name_plural = 'Model Trainings'
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Training: {self.name} ({self.get_status_display()})"


class ModelTrainingLog(models.Model):
    """Logs for model training processes."""
    training = models.ForeignKey(
        ModelTraining,
        on_delete=models.CASCADE,
        related_name='logs'
    )
    
    epoch = models.IntegerField(null=True, blank=True)
    step = models.IntegerField(null=True, blank=True)
    
    train_loss = models.FloatField(null=True, blank=True)
    val_loss = models.FloatField(null=True, blank=True)
    
    train_accuracy = models.FloatField(null=True, blank=True)
    val_accuracy = models.FloatField(null=True, blank=True)
    
    timestamp = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = 'Training Log'
        verbose_name_plural = 'Training Logs'
        ordering = ['training', 'epoch', 'step']
    
    def __str__(self):
        return f"Log for {self.training.name} - Epoch {self.epoch}, Step {self.step}"