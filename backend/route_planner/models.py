"""
Models for the route_planner app.
"""

from django.db import models
from django.conf import settings
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

User = settings.AUTH_USER_MODEL


class Location(models.Model):
    """
    Represents a geographical location for route planning.
    """
    name = models.CharField(_('location name'), max_length=255)
    latitude = models.DecimalField(_('latitude'), max_digits=10, decimal_places=7)
    longitude = models.DecimalField(_('longitude'), max_digits=10, decimal_places=7)
    description = models.TextField(_('description'), blank=True)
    address = models.TextField(_('address'), blank=True)
    is_popular = models.BooleanField(_('is popular location'), default=False)
    created_at = models.DateTimeField(_('created at'), auto_now_add=True)
    updated_at = models.DateTimeField(_('updated at'), auto_now=True)

    class Meta:
        verbose_name = _('location')
        verbose_name_plural = _('locations')
        indexes = [
            models.Index(fields=['latitude', 'longitude']),
            models.Index(fields=['is_popular']),
        ]
    
    def __str__(self):
        return self.name


class Route(models.Model):
    """
    Represents a route segment between two locations.
    """
    origin = models.ForeignKey(Location, on_delete=models.CASCADE, related_name='routes_from', verbose_name=_('origin'))
    destination = models.ForeignKey(Location, on_delete=models.CASCADE, related_name='routes_to', verbose_name=_('destination'))
    distance_km = models.DecimalField(_('distance (km)'), max_digits=7, decimal_places=2)
    normal_duration_minutes = models.PositiveIntegerField(_('normal duration (minutes)'))
    created_at = models.DateTimeField(_('created at'), auto_now_add=True)
    updated_at = models.DateTimeField(_('updated at'), auto_now=True)
    
    class Meta:
        verbose_name = _('route')
        verbose_name_plural = _('routes')
        unique_together = ('origin', 'destination')
        indexes = [
            models.Index(fields=['origin', 'destination']),
        ]
    
    def __str__(self):
        return f"{self.origin} → {self.destination} ({self.distance_km} km)"


class RouteTrafficData(models.Model):
    """
    Historical traffic data for route segments at specific times.
    """
    route = models.ForeignKey(Route, on_delete=models.CASCADE, related_name='traffic_data', verbose_name=_('route'))
    day_of_week = models.PositiveSmallIntegerField(_('day of week'), choices=[(i, i) for i in range(7)])  # 0=Monday, 6=Sunday
    hour_of_day = models.PositiveSmallIntegerField(_('hour of day'), choices=[(i, i) for i in range(24)])
    traffic_factor = models.DecimalField(_('traffic factor'), max_digits=4, decimal_places=2, 
                                      help_text=_('Multiplier for travel time. 1.0 = normal, 2.0 = twice as long'))
    last_updated = models.DateTimeField(_('last updated'), auto_now=True)
    
    class Meta:
        verbose_name = _('route traffic data')
        verbose_name_plural = _('route traffic data')
        unique_together = ('route', 'day_of_week', 'hour_of_day')
        indexes = [
            models.Index(fields=['route', 'day_of_week', 'hour_of_day']),
        ]
    
    def __str__(self):
        day_names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        return f"{self.route} - {day_names[self.day_of_week]} {self.hour_of_day}:00 (factor: {self.traffic_factor})"


class RouteRecommendation(models.Model):
    """
    Stores route recommendations requested by users.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='route_recommendations', verbose_name=_('user'))
    origin = models.ForeignKey(Location, on_delete=models.CASCADE, related_name='recommendations_from', verbose_name=_('origin'))
    destination = models.ForeignKey(Location, on_delete=models.CASCADE, related_name='recommendations_to', verbose_name=_('destination'))
    travel_datetime = models.DateTimeField(_('travel datetime'))
    created_at = models.DateTimeField(_('created at'), auto_now_add=True)
    is_favorite = models.BooleanField(_('is favorite'), default=False)
    
    class Meta:
        verbose_name = _('route recommendation')
        verbose_name_plural = _('route recommendations')
        ordering = ['-created_at']
    
    def __str__(self):
        return f"{self.origin} to {self.destination} ({self.travel_datetime})"


class RecommendedRoute(models.Model):
    """
    Individual route options within a recommendation.
    """
    class RouteType(models.TextChoices):
        FASTEST = 'fastest', _('Fastest')
        SHORTEST = 'shortest', _('Shortest')
        ALTERNATIVE = 'alternative', _('Alternative')
    
    recommendation = models.ForeignKey(RouteRecommendation, on_delete=models.CASCADE, 
                                      related_name='routes', verbose_name=_('recommendation'))
    route_type = models.CharField(_('route type'), max_length=20, choices=RouteType.choices)
    total_distance_km = models.DecimalField(_('total distance (km)'), max_digits=7, decimal_places=2)
    estimated_duration_minutes = models.PositiveIntegerField(_('estimated duration (minutes)'))
    route_data = models.JSONField(_('route data'), help_text=_('JSON containing the full route details'))
    
    class Meta:
        verbose_name = _('recommended route')
        verbose_name_plural = _('recommended routes')
    
    def __str__(self):
        return f"{self.get_route_type_display()} route: {self.total_distance_km} km, {self.estimated_duration_minutes} min"


class TrafficJam(models.Model):
    """
    User-reported traffic jams/congestion.
    """
    class Severity(models.TextChoices):
        LOW = 'low', _('Low')
        MEDIUM = 'medium', _('Medium')
        HIGH = 'high', _('High')
        SEVERE = 'severe', _('Severe')
    
    location = models.ForeignKey(Location, on_delete=models.CASCADE, related_name='traffic_jams', verbose_name=_('location'))
    reported_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reported_jams', verbose_name=_('reported by'))
    severity = models.CharField(_('severity'), max_length=20, choices=Severity.choices)
    description = models.TextField(_('description'), blank=True)
    start_time = models.DateTimeField(_('start time'), default=timezone.now)
    end_time = models.DateTimeField(_('end time'), null=True, blank=True)
    is_active = models.BooleanField(_('is active'), default=True)
    
    class Meta:
        verbose_name = _('traffic jam')
        verbose_name_plural = _('traffic jams')
        ordering = ['-start_time']
        indexes = [
            models.Index(fields=['is_active']),
            models.Index(fields=['severity']),
        ]
    
    def __str__(self):
        status = "Active" if self.is_active else "Resolved"
        return f"{status} {self.get_severity_display()} jam at {self.location}"
    
    @property
    def duration_minutes(self):
        """Return the duration of the traffic jam in minutes."""
        if not self.is_active:
            if self.end_time:
                return int((self.end_time - self.start_time).total_seconds() / 60)
        # For active jams, calculate the time elapsed so far
        return int((timezone.now() - self.start_time).total_seconds() / 60)
    
    def resolve(self):
        """Mark the traffic jam as resolved."""
        self.is_active = False
        self.end_time = timezone.now()
        self.save()