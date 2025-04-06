"""
Models for route recommendation system.
"""
import uuid
from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _
from django.utils import timezone


class TrafficData(models.Model):
    """
    Model to store historical traffic data for machine learning.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    origin_lat = models.FloatField(_('origin latitude'))
    origin_lng = models.FloatField(_('origin longitude'))
    destination_lat = models.FloatField(_('destination latitude'))
    destination_lng = models.FloatField(_('destination longitude'))
    traffic_level = models.IntegerField(_('traffic level (0-100)'))
    travel_time_seconds = models.IntegerField(_('travel time in seconds'))
    distance_meters = models.IntegerField(_('distance in meters'))
    timestamp = models.DateTimeField(_('timestamp'), default=timezone.now)
    day_of_week = models.IntegerField(_('day of week (0-6, Monday is 0)'))
    hour_of_day = models.IntegerField(_('hour of day (0-23)'))
    is_holiday = models.BooleanField(_('is holiday'), default=False)
    is_rush_hour = models.BooleanField(_('is rush hour'), default=False)
    weather_condition = models.CharField(_('weather condition'), max_length=50, blank=True)
    
    class Meta:
        verbose_name = _('traffic data')
        verbose_name_plural = _('traffic data')
        ordering = ['-timestamp']
        indexes = [
            models.Index(fields=['day_of_week', 'hour_of_day']),
            models.Index(fields=['origin_lat', 'origin_lng']),
            models.Index(fields=['destination_lat', 'destination_lng']),
        ]
        
    def __str__(self):
        """String representation of traffic data."""
        return f"Traffic data from ({self.origin_lat}, {self.origin_lng}) to ({self.destination_lat}, {self.destination_lng}) at {self.timestamp}"


class RouteRecommendation(models.Model):
    """
    Model to store route recommendations.
    """
    class RouteType(models.TextChoices):
        """Types of routes."""
        FASTEST = 'fastest', _('Fastest Route')
        ALTERNATE = 'alternate', _('Alternate Route')
        LEAST_TRAFFIC = 'least_traffic', _('Least Traffic Route')
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='route_recommendations'
    )
    origin_lat = models.FloatField(_('origin latitude'))
    origin_lng = models.FloatField(_('origin longitude'))
    destination_lat = models.FloatField(_('destination latitude'))
    destination_lng = models.FloatField(_('destination longitude'))
    route_type = models.CharField(
        _('route type'),
        max_length=20,
        choices=RouteType.choices,
        default=RouteType.FASTEST
    )
    travel_time_seconds = models.IntegerField(_('estimated travel time in seconds'))
    distance_meters = models.IntegerField(_('distance in meters'))
    created_at = models.DateTimeField(_('created at'), default=timezone.now)
    route_data = models.JSONField(_('route data from Google Maps API'))
    traffic_level = models.IntegerField(_('traffic level (0-100)'), default=0)
    is_active = models.BooleanField(_('is active'), default=True)
    
    class Meta:
        verbose_name = _('route recommendation')
        verbose_name_plural = _('route recommendations')
        ordering = ['-created_at']
        
    def __str__(self):
        """String representation of route recommendation."""
        return f"{self.get_route_type_display()} for {self.user.username} at {self.created_at}"


class PeakTrafficTime(models.Model):
    """
    Model to define peak traffic times for different areas.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    area_name = models.CharField(_('area name'), max_length=100)
    center_lat = models.FloatField(_('center latitude'))
    center_lng = models.FloatField(_('center longitude'))
    radius_meters = models.IntegerField(_('radius in meters'))
    day_of_week = models.IntegerField(_('day of week (0-6, Monday is 0)'))
    start_hour = models.IntegerField(_('start hour (0-23)'))
    end_hour = models.IntegerField(_('end hour (0-23)'))
    traffic_level = models.IntegerField(_('average traffic level (0-100)'))
    created_at = models.DateTimeField(_('created at'), default=timezone.now)
    updated_at = models.DateTimeField(_('updated at'), auto_now=True)
    
    class Meta:
        verbose_name = _('peak traffic time')
        verbose_name_plural = _('peak traffic times')
        ordering = ['area_name', 'day_of_week', 'start_hour']
        indexes = [
            models.Index(fields=['day_of_week', 'start_hour', 'end_hour']),
            models.Index(fields=['area_name']),
        ]
        
    def __str__(self):
        """String representation of peak traffic time."""
        days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
        return f"{self.area_name} on {days[self.day_of_week]} from {self.start_hour}:00 to {self.end_hour}:00"
    
    @property
    def is_current(self):
        """Check if current time falls within this peak traffic time."""
        now = timezone.now()
        return (
            self.day_of_week == now.weekday() and
            self.start_hour <= now.hour < self.end_hour
        )