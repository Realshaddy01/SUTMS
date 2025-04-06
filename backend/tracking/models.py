"""
Models for real-time tracking system.
"""
import uuid
from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _
from django.utils import timezone

class OfficerLocation(models.Model):
    """
    Model to store officer real-time location data.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    officer = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='locations',
        help_text=_('The officer being tracked')
    )
    latitude = models.FloatField(_('latitude'))
    longitude = models.FloatField(_('longitude'))
    accuracy = models.FloatField(_('accuracy in meters'), default=0)
    speed = models.FloatField(_('speed in km/h'), default=0)
    heading = models.FloatField(_('heading in degrees'), default=0)
    battery_level = models.FloatField(_('battery level percentage'), default=0)
    last_updated = models.DateTimeField(_('last updated'), default=timezone.now)
    
    class Meta:
        verbose_name = _('officer location')
        verbose_name_plural = _('officer locations')
        ordering = ['-last_updated']
        
    def __str__(self):
        """String representation of the officer location."""
        return f"{self.officer.username} @ {self.last_updated}"
    
    def is_recent(self):
        """Check if the location data is recent (within the last hour)."""
        return self.last_updated >= timezone.now() - timezone.timedelta(hours=1)
    
    
class TrafficSignal(models.Model):
    """
    Model to represent traffic signals/lights.
    """
    class Status(models.TextChoices):
        """Status choices for traffic signals."""
        OPERATIONAL = 'operational', _('Operational')
        MAINTENANCE = 'maintenance', _('Under Maintenance')
        OFFLINE = 'offline', _('Offline')
        WARNING = 'warning', _('Warning Mode')
        MALFUNCTION = 'malfunction', _('Malfunction')
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(_('name'), max_length=100)
    code = models.CharField(_('signal code'), max_length=50, unique=True)
    latitude = models.FloatField(_('latitude'))
    longitude = models.FloatField(_('longitude'))
    status = models.CharField(
        _('status'),
        max_length=20,
        choices=Status.choices,
        default=Status.OPERATIONAL
    )
    installed_date = models.DateField(_('installation date'), null=True, blank=True)
    last_maintained = models.DateField(_('last maintenance'), null=True, blank=True)
    last_updated = models.DateTimeField(_('last updated'), auto_now=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='updated_signals'
    )
    notes = models.TextField(_('notes'), blank=True)
    
    class Meta:
        verbose_name = _('traffic signal')
        verbose_name_plural = _('traffic signals')
        ordering = ['name']
        
    def __str__(self):
        """String representation of the traffic signal."""
        return f"{self.name} ({self.code})"
    
    def is_working(self):
        """Check if the signal is working properly."""
        return self.status == self.Status.OPERATIONAL
    
    def needs_maintenance(self):
        """Check if the signal needs maintenance."""
        return self.status in [self.Status.MAINTENANCE, self.Status.MALFUNCTION]
    
    
class Incident(models.Model):
    """
    Model to track traffic incidents.
    """
    class Status(models.TextChoices):
        """Status choices for incidents."""
        REPORTED = 'reported', _('Reported')
        RESPONDING = 'responding', _('Responding')
        IN_PROGRESS = 'in_progress', _('In Progress')
        RESOLVED = 'resolved', _('Resolved')
        CANCELLED = 'cancelled', _('Cancelled')
    
    class Severity(models.TextChoices):
        """Severity levels for incidents."""
        LOW = 'low', _('Low')
        MEDIUM = 'medium', _('Medium')
        HIGH = 'high', _('High')
        CRITICAL = 'critical', _('Critical')
        
    class IncidentType(models.TextChoices):
        """Types of traffic incidents."""
        ACCIDENT = 'accident', _('Accident')
        BREAKDOWN = 'breakdown', _('Vehicle Breakdown')
        OBSTRUCTION = 'obstruction', _('Road Obstruction')
        WEATHER = 'weather', _('Weather Condition')
        CONSTRUCTION = 'construction', _('Construction')
        SIGNAL_ISSUE = 'signal_issue', _('Traffic Signal Issue')
        CONGESTION = 'congestion', _('Traffic Congestion')
        OTHER = 'other', _('Other')
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    incident_type = models.CharField(
        _('incident type'),
        max_length=20,
        choices=IncidentType.choices,
        default=IncidentType.OTHER
    )
    description = models.TextField(_('description'), blank=True)
    latitude = models.FloatField(_('latitude'))
    longitude = models.FloatField(_('longitude'))
    reported_at = models.DateTimeField(_('reported at'), default=timezone.now)
    reported_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        related_name='reported_incidents'
    )
    status = models.CharField(
        _('status'),
        max_length=20,
        choices=Status.choices,
        default=Status.REPORTED
    )
    severity = models.CharField(
        _('severity'),
        max_length=20,
        choices=Severity.choices,
        default=Severity.MEDIUM
    )
    updated_at = models.DateTimeField(_('updated at'), null=True, blank=True)
    updated_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='updated_incidents'
    )
    resolved_at = models.DateTimeField(_('resolved at'), null=True, blank=True)
    resolution = models.TextField(_('resolution'), blank=True)
    officers_assigned = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name='assigned_incidents'
    )
    
    class Meta:
        verbose_name = _('incident')
        verbose_name_plural = _('incidents')
        ordering = ['-reported_at']
        
    def __str__(self):
        """String representation of the incident."""
        return f"{self.get_incident_type_display()} at {self.reported_at}"
    
    def is_active(self):
        """Check if the incident is still active (not resolved or cancelled)."""
        return self.status not in [self.Status.RESOLVED, self.Status.CANCELLED]
    
    def is_high_priority(self):
        """Check if the incident is high priority."""
        return self.severity in [self.Severity.HIGH, self.Severity.CRITICAL]
    
    def mark_as_resolved(self, user, resolution=''):
        """Mark the incident as resolved."""
        self.status = self.Status.RESOLVED
        self.resolution = resolution
        self.resolved_at = timezone.now()
        self.updated_at = timezone.now()
        self.updated_by = user
        self.save()
        
    def assign_officer(self, officer):
        """Assign an officer to this incident."""
        self.officers_assigned.add(officer)
        if self.status == self.Status.REPORTED:
            self.status = self.Status.RESPONDING
            self.updated_at = timezone.now()
            self.updated_by = officer
            self.save()