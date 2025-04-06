"""
WebSocket consumers for real-time tracking.
"""
import json
import logging

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from django.utils import timezone
from django.contrib.auth import get_user_model

from .models import OfficerLocation, TrafficSignal, Incident

logger = logging.getLogger('sutms.tracking')

User = get_user_model()


class TrackingConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for real-time officer tracking.
    """
    async def connect(self):
        """Handle WebSocket connection."""
        self.user = self.scope.get('user')
        
        # Authenticate user
        if not self.user or not self.user.is_authenticated:
            logger.warning("Unauthorized tracking connection attempt")
            await self.close()
            return False
        
        # Only officers and admins can connect
        if not (self.user.is_officer or self.user.is_admin):
            logger.warning(f"Non-officer/admin user {self.user.username} attempted to connect to tracking")
            await self.close()
            return False
            
        # Join tracking group
        self.tracking_group = 'tracking'
        await self.channel_layer.group_add(
            self.tracking_group,
            self.channel_name
        )
        
        await self.accept()
        logger.info(f"User {self.user.username} connected to tracking WebSocket")
        
        # Send current locations of all active officers
        locations = await self.get_all_officer_locations()
        await self.send(text_data=json.dumps({
            'type': 'all_locations',
            'locations': locations
        }))

    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        # Leave tracking group
        if hasattr(self, 'tracking_group'):
            await self.channel_layer.group_discard(
                self.tracking_group,
                self.channel_name
            )
        logger.info(f"User {getattr(self, 'user', 'Unknown')}-{getattr(self.user, 'username', 'unknown')} disconnected from tracking WebSocket")

    async def receive(self, text_data):
        """Handle incoming WebSocket messages."""
        try:
            text_data_json = json.loads(text_data)
            message_type = text_data_json.get('type')
            
            # Handle different message types
            if message_type == 'location_update':
                # User sending their location
                latitude = text_data_json.get('latitude')
                longitude = text_data_json.get('longitude')
                accuracy = text_data_json.get('accuracy', 0)
                speed = text_data_json.get('speed', 0)
                heading = text_data_json.get('heading', 0)
                battery = text_data_json.get('battery', 0)
                
                # Save location to database
                location = await self.update_officer_location(
                    self.user, latitude, longitude, accuracy, speed, heading, battery
                )
                
                # Broadcast to all connected clients
                await self.channel_layer.group_send(
                    self.tracking_group,
                    {
                        'type': 'location_update',
                        'user_id': str(self.user.id),
                        'username': self.user.username,
                        'latitude': latitude,
                        'longitude': longitude,
                        'accuracy': accuracy,
                        'speed': speed,
                        'heading': heading,
                        'battery': battery,
                        'timestamp': str(timezone.now())
                    }
                )
                logger.debug(f"Location update from {self.user.username}: {latitude}, {longitude}")
                
            elif message_type == 'request_locations':
                # User requesting current locations of all officers
                locations = await self.get_all_officer_locations()
                await self.send(text_data=json.dumps({
                    'type': 'all_locations',
                    'locations': locations
                }))
                
            else:
                logger.warning(f"Unknown message type received: {message_type}")
                
        except json.JSONDecodeError:
            logger.error("Invalid JSON received via WebSocket")
        except Exception as e:
            logger.error(f"Error in WebSocket receive: {str(e)}")

    async def location_update(self, event):
        """Broadcast location update to WebSocket."""
        # Forward the location update to the client
        await self.send(text_data=json.dumps({
            'type': 'location_update',
            'user_id': event['user_id'],
            'username': event['username'],
            'latitude': event['latitude'],
            'longitude': event['longitude'],
            'accuracy': event['accuracy'],
            'speed': event['speed'],
            'heading': event['heading'],
            'battery': event['battery'],
            'timestamp': event['timestamp']
        }))

    @database_sync_to_async
    def update_officer_location(self, user, latitude, longitude, accuracy, speed, heading, battery):
        """Update officer location in the database."""
        # Get or create OfficerLocation object
        location, created = OfficerLocation.objects.update_or_create(
            officer=user,
            defaults={
                'latitude': latitude,
                'longitude': longitude,
                'accuracy': accuracy,
                'speed': speed,
                'heading': heading,
                'battery_level': battery,
                'last_updated': timezone.now()
            }
        )
        return {
            'id': str(location.id),
            'officer_id': str(location.officer.id),
            'officer_name': location.officer.get_full_name() or location.officer.username,
            'latitude': location.latitude,
            'longitude': location.longitude,
            'accuracy': location.accuracy,
            'speed': location.speed,
            'heading': location.heading,
            'battery_level': location.battery_level,
            'last_updated': str(location.last_updated)
        }

    @database_sync_to_async
    def get_all_officer_locations(self):
        """Get all officer locations from the database."""
        locations = OfficerLocation.objects.filter(
            last_updated__gte=timezone.now() - timezone.timedelta(hours=1)
        ).select_related('officer')
        
        return [
            {
                'id': str(location.id),
                'officer_id': str(location.officer.id),
                'officer_name': location.officer.get_full_name() or location.officer.username,
                'latitude': location.latitude,
                'longitude': location.longitude,
                'accuracy': location.accuracy,
                'speed': location.speed,
                'heading': location.heading,
                'battery_level': location.battery_level,
                'last_updated': str(location.last_updated)
            }
            for location in locations
        ]


class SignalConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for real-time traffic signal updates.
    """
    async def connect(self):
        """Handle WebSocket connection."""
        self.user = self.scope.get('user')
        
        # Authenticate user
        if not self.user or not self.user.is_authenticated:
            logger.warning("Unauthorized signal connection attempt")
            await self.close()
            return False
            
        # Join signal group
        self.signal_group = 'signals'
        await self.channel_layer.group_add(
            self.signal_group,
            self.channel_name
        )
        
        await self.accept()
        logger.info(f"User {self.user.username} connected to signals WebSocket")
        
        # Send current states of all traffic signals
        signals = await self.get_all_traffic_signals()
        await self.send(text_data=json.dumps({
            'type': 'all_signals',
            'signals': signals
        }))

    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        # Leave signal group
        if hasattr(self, 'signal_group'):
            await self.channel_layer.group_discard(
                self.signal_group,
                self.channel_name
            )
        logger.info(f"User {getattr(self, 'user', 'Unknown')}-{getattr(self.user, 'username', 'unknown')} disconnected from signals WebSocket")

    async def receive(self, text_data):
        """Handle incoming WebSocket messages."""
        try:
            text_data_json = json.loads(text_data)
            message_type = text_data_json.get('type')
            
            # Handle different message types
            if message_type == 'signal_update':
                # Check permissions - only officers and admins can update signals
                if not (self.user.is_officer or self.user.is_admin):
                    logger.warning(f"Non-officer/admin user {self.user.username} attempted to update traffic signal")
                    return
                
                signal_id = text_data_json.get('signal_id')
                status = text_data_json.get('status')
                
                # Update signal in database
                signal = await self.update_traffic_signal(signal_id, status, self.user)
                
                if signal:
                    # Broadcast to all connected clients
                    await self.channel_layer.group_send(
                        self.signal_group,
                        {
                            'type': 'signal_update',
                            'signal_id': str(signal['id']),
                            'name': signal['name'],
                            'status': signal['status'],
                            'updated_by': signal['updated_by'],
                            'timestamp': signal['last_updated']
                        }
                    )
                    logger.debug(f"Signal update from {self.user.username}: Signal {signal_id} to {status}")
                
            elif message_type == 'request_signals':
                # User requesting current states of all traffic signals
                signals = await self.get_all_traffic_signals()
                await self.send(text_data=json.dumps({
                    'type': 'all_signals',
                    'signals': signals
                }))
                
            else:
                logger.warning(f"Unknown message type received: {message_type}")
                
        except json.JSONDecodeError:
            logger.error("Invalid JSON received via WebSocket")
        except Exception as e:
            logger.error(f"Error in WebSocket receive: {str(e)}")

    async def signal_update(self, event):
        """Broadcast signal update to WebSocket."""
        # Forward the signal update to the client
        await self.send(text_data=json.dumps({
            'type': 'signal_update',
            'signal_id': event['signal_id'],
            'name': event['name'],
            'status': event['status'],
            'updated_by': event['updated_by'],
            'timestamp': event['timestamp']
        }))

    @database_sync_to_async
    def update_traffic_signal(self, signal_id, status, user):
        """Update traffic signal status in the database."""
        try:
            signal = TrafficSignal.objects.get(id=signal_id)
            signal.status = status
            signal.updated_by = user
            signal.last_updated = timezone.now()
            signal.save()
            
            return {
                'id': str(signal.id),
                'name': signal.name,
                'status': signal.status,
                'latitude': signal.latitude,
                'longitude': signal.longitude,
                'updated_by': user.get_full_name() or user.username,
                'last_updated': str(signal.last_updated)
            }
        except TrafficSignal.DoesNotExist:
            logger.error(f"Traffic signal with ID {signal_id} not found")
            return None
        except Exception as e:
            logger.error(f"Error updating traffic signal: {str(e)}")
            return None

    @database_sync_to_async
    def get_all_traffic_signals(self):
        """Get all traffic signals from the database."""
        signals = TrafficSignal.objects.all().select_related('updated_by')
        
        return [
            {
                'id': str(signal.id),
                'name': signal.name,
                'status': signal.status,
                'latitude': signal.latitude,
                'longitude': signal.longitude,
                'updated_by': signal.updated_by.get_full_name() if signal.updated_by else None,
                'last_updated': str(signal.last_updated)
            }
            for signal in signals
        ]


class IncidentConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for real-time traffic incident updates.
    """
    async def connect(self):
        """Handle WebSocket connection."""
        self.user = self.scope.get('user')
        
        # Authenticate user
        if not self.user or not self.user.is_authenticated:
            logger.warning("Unauthorized incident connection attempt")
            await self.close()
            return False
            
        # Join incident group
        self.incident_group = 'incidents'
        await self.channel_layer.group_add(
            self.incident_group,
            self.channel_name
        )
        
        await self.accept()
        logger.info(f"User {self.user.username} connected to incidents WebSocket")
        
        # Send current incidents
        incidents = await self.get_active_incidents()
        await self.send(text_data=json.dumps({
            'type': 'all_incidents',
            'incidents': incidents
        }))

    async def disconnect(self, close_code):
        """Handle WebSocket disconnection."""
        # Leave incident group
        if hasattr(self, 'incident_group'):
            await self.channel_layer.group_discard(
                self.incident_group,
                self.channel_name
            )
        logger.info(f"User {getattr(self, 'user', 'Unknown')}-{getattr(self.user, 'username', 'unknown')} disconnected from incidents WebSocket")

    async def receive(self, text_data):
        """Handle incoming WebSocket messages."""
        try:
            text_data_json = json.loads(text_data)
            message_type = text_data_json.get('type')
            
            # Handle different message types
            if message_type == 'report_incident':
                # Check permissions - only officers and admins can report incidents
                if not (self.user.is_officer or self.user.is_admin):
                    logger.warning(f"Non-officer/admin user {self.user.username} attempted to report incident")
                    return
                
                incident_type = text_data_json.get('incident_type')
                latitude = text_data_json.get('latitude')
                longitude = text_data_json.get('longitude')
                description = text_data_json.get('description', '')
                severity = text_data_json.get('severity', 'medium')
                
                # Save incident to database
                incident = await self.create_incident(
                    incident_type, latitude, longitude, description, severity, self.user
                )
                
                if incident:
                    # Broadcast to all connected clients
                    await self.channel_layer.group_send(
                        self.incident_group,
                        {
                            'type': 'incident_reported',
                            'incident_id': str(incident['id']),
                            'incident_type': incident['incident_type'],
                            'latitude': incident['latitude'],
                            'longitude': incident['longitude'],
                            'description': incident['description'],
                            'severity': incident['severity'],
                            'reported_by': incident['reported_by'],
                            'timestamp': incident['reported_at']
                        }
                    )
                    logger.debug(f"Incident reported by {self.user.username}: {incident_type} at {latitude}, {longitude}")
                
            elif message_type == 'update_incident':
                # Check permissions - only officers and admins can update incidents
                if not (self.user.is_officer or self.user.is_admin):
                    logger.warning(f"Non-officer/admin user {self.user.username} attempted to update incident")
                    return
                
                incident_id = text_data_json.get('incident_id')
                status = text_data_json.get('status')
                resolution = text_data_json.get('resolution', '')
                
                # Update incident in database
                incident = await self.update_incident(incident_id, status, resolution, self.user)
                
                if incident:
                    # Broadcast to all connected clients
                    await self.channel_layer.group_send(
                        self.incident_group,
                        {
                            'type': 'incident_updated',
                            'incident_id': str(incident['id']),
                            'status': incident['status'],
                            'resolution': incident['resolution'],
                            'updated_by': incident['updated_by'],
                            'timestamp': incident['updated_at']
                        }
                    )
                    logger.debug(f"Incident {incident_id} updated by {self.user.username}: status={status}")
                
            elif message_type == 'request_incidents':
                # User requesting active incidents
                active_only = text_data_json.get('active_only', True)
                incidents = await self.get_active_incidents() if active_only else await self.get_all_incidents()
                await self.send(text_data=json.dumps({
                    'type': 'all_incidents',
                    'incidents': incidents
                }))
                
            else:
                logger.warning(f"Unknown message type received: {message_type}")
                
        except json.JSONDecodeError:
            logger.error("Invalid JSON received via WebSocket")
        except Exception as e:
            logger.error(f"Error in WebSocket receive: {str(e)}")

    async def incident_reported(self, event):
        """Broadcast incident report to WebSocket."""
        # Forward the incident report to the client
        await self.send(text_data=json.dumps({
            'type': 'incident_reported',
            'incident_id': event['incident_id'],
            'incident_type': event['incident_type'],
            'latitude': event['latitude'],
            'longitude': event['longitude'],
            'description': event['description'],
            'severity': event['severity'],
            'reported_by': event['reported_by'],
            'timestamp': event['timestamp']
        }))

    async def incident_updated(self, event):
        """Broadcast incident update to WebSocket."""
        # Forward the incident update to the client
        await self.send(text_data=json.dumps({
            'type': 'incident_updated',
            'incident_id': event['incident_id'],
            'status': event['status'],
            'resolution': event['resolution'],
            'updated_by': event['updated_by'],
            'timestamp': event['timestamp']
        }))

    @database_sync_to_async
    def create_incident(self, incident_type, latitude, longitude, description, severity, user):
        """Create a new traffic incident in the database."""
        try:
            incident = Incident.objects.create(
                incident_type=incident_type,
                latitude=latitude,
                longitude=longitude,
                description=description,
                severity=severity,
                reported_by=user,
                reported_at=timezone.now(),
                status=Incident.Status.REPORTED
            )
            
            return {
                'id': str(incident.id),
                'incident_type': incident.incident_type,
                'latitude': incident.latitude,
                'longitude': incident.longitude,
                'description': incident.description,
                'severity': incident.severity,
                'status': incident.status,
                'reported_by': user.get_full_name() or user.username,
                'reported_at': str(incident.reported_at)
            }
        except Exception as e:
            logger.error(f"Error creating incident: {str(e)}")
            return None

    @database_sync_to_async
    def update_incident(self, incident_id, status, resolution, user):
        """Update a traffic incident in the database."""
        try:
            incident = Incident.objects.get(id=incident_id)
            incident.status = status
            incident.resolution = resolution
            incident.updated_by = user
            incident.updated_at = timezone.now()
            incident.save()
            
            return {
                'id': str(incident.id),
                'status': incident.status,
                'resolution': incident.resolution,
                'updated_by': user.get_full_name() or user.username,
                'updated_at': str(incident.updated_at)
            }
        except Incident.DoesNotExist:
            logger.error(f"Incident with ID {incident_id} not found")
            return None
        except Exception as e:
            logger.error(f"Error updating incident: {str(e)}")
            return None

    @database_sync_to_async
    def get_active_incidents(self):
        """Get active traffic incidents from the database."""
        incidents = Incident.objects.exclude(
            status=Incident.Status.RESOLVED
        ).select_related('reported_by', 'updated_by')
        
        return [
            {
                'id': str(incident.id),
                'incident_type': incident.incident_type,
                'latitude': incident.latitude,
                'longitude': incident.longitude,
                'description': incident.description,
                'severity': incident.severity,
                'status': incident.status,
                'resolution': incident.resolution,
                'reported_by': incident.reported_by.get_full_name() or incident.reported_by.username,
                'reported_at': str(incident.reported_at),
                'updated_by': incident.updated_by.get_full_name() or incident.updated_by.username if incident.updated_by else None,
                'updated_at': str(incident.updated_at) if incident.updated_at else None
            }
            for incident in incidents
        ]

    @database_sync_to_async
    def get_all_incidents(self):
        """Get all traffic incidents from the database."""
        incidents = Incident.objects.all().select_related('reported_by', 'updated_by')
        
        return [
            {
                'id': str(incident.id),
                'incident_type': incident.incident_type,
                'latitude': incident.latitude,
                'longitude': incident.longitude,
                'description': incident.description,
                'severity': incident.severity,
                'status': incident.status,
                'resolution': incident.resolution,
                'reported_by': incident.reported_by.get_full_name() or incident.reported_by.username,
                'reported_at': str(incident.reported_at),
                'updated_by': incident.updated_by.get_full_name() or incident.updated_by.username if incident.updated_by else None,
                'updated_at': str(incident.updated_at) if incident.updated_at else None
            }
            for incident in incidents
        ]