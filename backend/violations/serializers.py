from rest_framework import serializers
from .models import ViolationType, Violation, ViolationAppeal
from vehicles.serializers import VehicleSerializer

class ViolationTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ViolationType
        fields = '__all__'

class ViolationSerializer(serializers.ModelSerializer):
    vehicle_details = VehicleSerializer(source='vehicle', read_only=True)
    violation_type_details = ViolationTypeSerializer(source='violation_type', read_only=True)
    reporter_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Violation
        fields = '__all__'
        read_only_fields = ['reported_by', 'fine_amount', 'is_paid', 'payment_date']
    
    def get_reporter_name(self, obj):
        return f"{obj.reported_by.first_name} {obj.reported_by.last_name}"
    
    def create(self, validated_data):
        # Set the fine amount from the violation type
        validated_data['fine_amount'] = validated_data['violation_type'].fine_amount
        # Set the reporter to the current user
        validated_data['reported_by'] = self.context['request'].user
        return super().create(validated_data)

class ViolationAppealSerializer(serializers.ModelSerializer):
    submitter_name = serializers.SerializerMethodField()
    reviewer_name = serializers.SerializerMethodField()
    
    class Meta:
        model = ViolationAppeal
        fields = '__all__'
        read_only_fields = ['submitted_by', 'status', 'reviewed_by', 'reviewed_at', 'reviewer_comments']
    
    def get_submitter_name(self, obj):
        return f"{obj.submitted_by.first_name} {obj.submitted_by.last_name}"
    
    def get_reviewer_name(self, obj):
        if obj.reviewed_by:
            return f"{obj.reviewed_by.first_name} {obj.reviewed_by.last_name}"
        return None
    
    def create(self, validated_data):
        # Set the submitter to the current user
        validated_data['submitted_by'] = self.context['request'].user
        # Update the violation status to disputed
        violation = validated_data['violation']
        violation.status = 'disputed'
        violation.save()
        return super().create(validated_data)

