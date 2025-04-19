"""
Models for the violations app.
"""
from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _
import os
from django.utils import timezone
from vehicles.models import Vehicle
from django.core.validators import MinValueValidator


class ViolationType(models.Model):
    """Traffic violation types with predefined fine amounts."""
    
    name = models.CharField(max_length=100)
    code = models.CharField(max_length=20, blank=True, null=True)
    description = models.TextField()
    is_active = models.BooleanField(default=True)
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    penalty_points = models.PositiveIntegerField(default=0)
    
    def __str__(self):
        return f"{self.name} - {self.description}"


class Violation(models.Model):
    """Traffic violation record."""
    
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('paid', 'Paid'),
        ('cancelled', 'Cancelled'),
    ]

    vehicle = models.ForeignKey(Vehicle, on_delete=models.CASCADE, related_name='violations')
    violation_type = models.ForeignKey(ViolationType, on_delete=models.PROTECT)
    violation_date = models.DateTimeField(default=timezone.now)
    location = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    evidence_image = models.ImageField(upload_to='violations/evidence/', null=True, blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(0)])
    paid_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0, validators=[MinValueValidator(0)])
    payment_date = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.vehicle.license_plate} - {self.violation_type.name} ({self.status})"

    def save(self, *args, **kwargs):
        if self.status == 'paid' and not self.payment_date:
            self.payment_date = timezone.now()
        super().save(*args, **kwargs)


class ViolationAppeal(models.Model):
    """Appeal against a violation."""
    
    class Status(models.TextChoices):
        """Appeal status choices."""
        PENDING = 'pending', _('Pending')
        APPROVED = 'approved', _('Approved')
        REJECTED = 'rejected', _('Rejected')
    
    violation = models.ForeignKey(
        Violation,
        on_delete=models.CASCADE,
        related_name='appeals'
    )
    appealed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='appeals'
    )
    reason = models.TextField(_('reason'))
    evidence_file = models.FileField(_('evidence file'), upload_to='appeal_evidence', null=True, blank=True)
    status = models.CharField(
        _('status'),
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='appeal_reviews'
    )
    review_date = models.DateTimeField(_('review date'), null=True, blank=True)
    review_notes = models.TextField(_('review notes'), blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('violation appeal')
        verbose_name_plural = _('violation appeals')
        ordering = ['-created_at']
    
    def __str__(self):
        return f"Appeal for {self.violation} by {self.appealed_by.get_full_name() or self.appealed_by.username}"


class Notification(models.Model):
    """Model for user notifications."""
    NOTIFICATION_TYPES = (
        ('violation', 'Violation'),
        ('appeal', 'Appeal'),
        ('payment', 'Payment'),
        ('system', 'System'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    title = models.CharField(max_length=255)
    message = models.TextField()
    notification_type = models.CharField(
        max_length=20,
        choices=NOTIFICATION_TYPES,
        default='system'
    )
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    link = models.CharField(max_length=255, blank=True, null=True)
    related_violation = models.ForeignKey(
        'Violation',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='notifications'
    )

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.notification_type}: {self.title} for {self.user}"