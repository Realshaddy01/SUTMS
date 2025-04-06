"""
Signal handlers for the tracking app.
"""
import json
import logging

from django.db.models.signals import post_save
from django.dispatch import receiver
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

from tracking.models import OfficerLocation, TrafficSignal, TrafficIncident
from tracking.serializers import (
    OfficerLocationSerializer,
    TrafficSignalSerializer,
    TrafficIncidentSerializer,
)

logger = logging.getLogger(__name__)
channel_layer = get_channel_layer()


@receiver(post_save, sender=OfficerLocation)
def officer_location_saved(sender, instance, created, **kwargs):
    """
    Signal handler for OfficerLocation model post_save event.
    """
    try:
        # Serialize the officer location
        serializer = OfficerLocationSerializer(instance)
        location_data = serializer.data
        
        # Send message to tracking group
        async_to_sync(channel_layer.group_send)(
            'tracking_updates',
            {
                'type': 'officer_location_update',
                'location': location_data,
            }
        )
        
        logger.info(f"Officer location update sent: {instance.officer.username}")
    except Exception as e:
        logger.exception(f"Error sending officer location update: {e}")


@receiver(post_save, sender=TrafficSignal)
def traffic_signal_saved(sender, instance, created, **kwargs):
    """
    Signal handler for TrafficSignal model post_save event.
    """
    try:
        # Serialize the traffic signal
        serializer = TrafficSignalSerializer(instance)
        signal_data = serializer.data
        
        # Send message to tracking group
        async_to_sync(channel_layer.group_send)(
            'tracking_updates',
            {
                'type': 'signal_phase_update',
                'signal': signal_data,
            }
        )
        
        logger.info(f"Traffic signal update sent: {instance.name}")
    except Exception as e:
        logger.exception(f"Error sending traffic signal update: {e}")


@receiver(post_save, sender=TrafficIncident)
def traffic_incident_saved(sender, instance, created, **kwargs):
    """
    Signal handler for TrafficIncident model post_save event.
    """
    try:
        # Serialize the traffic incident
        serializer = TrafficIncidentSerializer(instance)
        incident_data = serializer.data
        
        # Send message to tracking group
        async_to_sync(channel_layer.group_send)(
            'tracking_updates',
            {
                'type': 'incident_reported' if created else 'incident_updated',
                'incident': incident_data,
            }
        )
        
        logger.info(f"Traffic incident {'reported' if created else 'updated'}")
    except Exception as e:
        logger.exception(f"Error sending traffic incident update: {e}")