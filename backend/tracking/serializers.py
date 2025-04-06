"""
Serializers for the tracking app models.
"""
from rest_framework import serializers

from tracking.models import OfficerLocation, TrafficSignal, TrafficIncident


class OfficerLocationSerializer(serializers.ModelSerializer):
    """
    Serializer for OfficerLocation model.
    """
    officer_name = serializers.SerializerMethodField()
    officer_id = serializers.SerializerMethodField()
    
    class Meta:
        model = OfficerLocation
        fields = [
            'id', 'officer_id', 'officer_name', 'latitude', 'longitude',
            'accuracy', 'speed', 'heading', 'is_active', 'battery_level',
            'timestamp'
        ]
    
    def get_officer_name(self, obj):
        """
        Get officer name.
        """
        return obj.officer.username if obj.officer else None
    
    def get_officer_id(self, obj):
        """
        Get officer ID.
        """
        return obj.officer.id if obj.officer else None


class TrafficSignalSerializer(serializers.ModelSerializer):
    """
    Serializer for TrafficSignal model.
    """
    last_updated_by_name = serializers.SerializerMethodField()
    
    class Meta:
        model = TrafficSignal
        fields = [
            'id', 'name', 'street_name', 'latitude', 'longitude',
            'status', 'current_phase', 'time_remaining', 'is_automated',
            'last_updated', 'last_updated_by', 'last_updated_by_name'
        ]
    
    def get_last_updated_by_name(self, obj):
        """
        Get last updated by name.
        """
        return obj.last_updated_by.username if obj.last_updated_by else None


class TrafficIncidentSerializer(serializers.ModelSerializer):
    """
    Serializer for TrafficIncident model.
    """
    incident_type_display = serializers.SerializerMethodField()
    severity_display = serializers.SerializerMethodField()
    reported_by_name = serializers.SerializerMethodField()
    verified_by_name = serializers.SerializerMethodField()
    
    class Meta:
        model = TrafficIncident
        fields = [
            'id', 'incident_type', 'incident_type_display', 'description',
            'location', 'latitude', 'longitude', 'severity', 'severity_display',
            'is_verified', 'is_resolved', 'is_active', 'reported_by_id',
            'reported_by_name', 'verified_by_id', 'verified_by_name',
            'reported_at', 'verified_at', 'resolved_at'
        ]
    
    def get_incident_type_display(self, obj):
        """
        Get display value for incident type.
        """
        return obj.incident_type_display
    
    def get_severity_display(self, obj):
        """
        Get display value for severity.
        """
        return obj.severity_display
    
    def get_reported_by_name(self, obj):
        """
        Get name of user who reported the incident.
        """
        return obj.reported_by.username if obj.reported_by else None
    
    def get_verified_by_name(self, obj):
        """
        Get name of officer who verified the incident.
        """
        return obj.verified_by.username if obj.verified_by else None
    
    def get_reported_by_id(self, obj):
        """
        Get ID of user who reported the incident.
        """
        return obj.reported_by.id if obj.reported_by else None
    
    def get_verified_by_id(self, obj):
        """
        Get ID of officer who verified the incident.
        """
        return obj.verified_by.id if obj.verified_by else None