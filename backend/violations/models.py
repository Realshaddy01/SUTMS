"""
Models for the violations app.
"""
from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _


class ViolationType(models.Model):
    """Traffic violation types with predefined fine amounts."""
    
    name = models.CharField(_('name'), max_length=100)
    code = models.CharField(_('code'), max_length=20, unique=True)
    description = models.TextField(_('description'), blank=True)
    base_fine = models.DecimalField(_('base fine'), max_digits=10, decimal_places=2)
    is_active = models.BooleanField(_('is active'), default=True)
    severity = models.CharField(_('severity'), max_length=20, choices=[
        ('low', _('Low')),
        ('medium', _('Medium')),
        ('high', _('High')),
        ('severe', _('Severe')),
    ], default='medium')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('violation type')
        verbose_name_plural = _('violation types')
        ordering = ['name']
    
    def __str__(self):
        return f"{self.name} ({self.code})"


class Violation(models.Model):
    """Traffic violation record."""
    
    class Status(models.TextChoices):
        """Violation status choices."""
        PENDING = 'pending', _('Pending')
        APPROVED = 'approved', _('Approved')
        REJECTED = 'rejected', _('Rejected')
        PAID = 'paid', _('Paid')
        APPEALED = 'appealed', _('Appealed')
        APPEAL_APPROVED = 'appeal_approved', _('Appeal Approved')
        APPEAL_REJECTED = 'appeal_rejected', _('Appeal Rejected')
    
    violation_type = models.ForeignKey(
        ViolationType,
        on_delete=models.PROTECT,
        related_name='violations'
    )
    vehicle = models.ForeignKey(
        'vehicles.Vehicle',
        on_delete=models.CASCADE,
        related_name='violations'
    )
    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='reported_violations'
    )
    location = models.CharField(_('location'), max_length=255)
    latitude = models.DecimalField(_('latitude'), max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(_('longitude'), max_digits=9, decimal_places=6, null=True, blank=True)
    timestamp = models.DateTimeField(_('timestamp'))
    description = models.TextField(_('description'), blank=True)
    evidence_image = models.ImageField(_('evidence image'), upload_to='violation_evidence', null=True, blank=True)
    license_plate_image = models.ImageField(_('license plate image'), upload_to='license_plates', null=True, blank=True)
    fine_amount = models.DecimalField(_('fine amount'), max_digits=10, decimal_places=2)
    status = models.CharField(
        _('status'),
        max_length=20,
        choices=Status.choices,
        default=Status.PENDING
    )
    appeal_reason = models.TextField(_('appeal reason'), blank=True)
    appeal_date = models.DateTimeField(_('appeal date'), null=True, blank=True)
    appeal_decision = models.TextField(_('appeal decision'), blank=True)
    appeal_decision_date = models.DateTimeField(_('appeal decision date'), null=True, blank=True)
    appeal_decided_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='appeal_decisions'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = _('violation')
        verbose_name_plural = _('violations')
        ordering = ['-timestamp']
    
    def __str__(self):
        return f"{self.violation_type} - {self.vehicle.license_plate} ({self.timestamp.strftime('%Y-%m-%d')})"


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
    """User notifications."""
    
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='notifications'
    )
    title = models.CharField(_('title'), max_length=100)
    message = models.TextField(_('message'))
    is_read = models.BooleanField(_('is read'), default=False)
    notification_type = models.CharField(
        _('notification type'), 
        max_length=20,
        default='general',
        choices=[
            ('general', _('General')),
            ('violation', _('Violation')),
            ('appeal', _('Appeal')),
            ('payment', _('Payment')),
            ('system', _('System')),
        ]
    )
    link = models.CharField(_('link'), max_length=255, blank=True)
    related_violation = models.ForeignKey(
        Violation,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name='notifications'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    
    class Meta:
        verbose_name = _('notification')
        verbose_name_plural = _('notifications')
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.title} ({self.user.email})"