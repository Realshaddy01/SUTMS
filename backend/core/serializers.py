from django.contrib.auth.models import User
from rest_framework import serializers
from .models import (
    Profile, Vehicle, VehicleOwner, TrafficOfficer, 
    Violation, ViolationType, Payment, Notification
)

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'first_name', 'last_name']
        read_only_fields = ['id']

class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = Profile
        fields = ['id', 'user', 'profile_image', 'created_at', 'updated_at']
        read_only_fields = ['id', 'user', 'created_at', 'updated_at']

class VehicleOwnerSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    
    class Meta:
        model = VehicleOwner
        fields = ['id', 'user', 'citizenship_number', 'phone_number', 'address', 'profile']
        read_only_fields = ['id', 'profile']

class TrafficOfficerSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    
    class Meta:
        model = TrafficOfficer
        fields = ['id', 'user', 'badge_number', 'department', 'jurisdiction', 'profile']
        read_only_fields = ['id', 'profile']

class VehicleSerializer(serializers.ModelSerializer):
    qr_code_url = serializers.SerializerMethodField()
    owner_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Vehicle
        fields = [
            'id', 'owner', 'license_plate', 'make', 'model', 'year', 
            'color', 'registration_number', 'qr_code', 'qr_code_url',
            'owner_name', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'qr_code', 'created_at', 'updated_at']
    
    def get_qr_code_url(self, obj):
        if obj.qr_code:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.qr_code.url)
            return obj.qr_code.url
        return None
    
    def get_owner_name(self, obj):
        return f"{obj.owner.user.first_name} {obj.owner.user.last_name}"

class ViolationTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ViolationType
        fields = ['id', 'name', 'description', 'fine_amount']
        read_only_fields = ['id']

class ViolationSerializer(serializers.ModelSerializer):
    violation_type_name = serializers.SerializerMethodField()
    vehicle_license_plate = serializers.SerializerMethodField()
    evidence_image_url = serializers.SerializerMethodField()
    payment_status = serializers.SerializerMethodField()
    
    class Meta:
        model = Violation
        fields = [
            'id', 'vehicle', 'vehicle_license_plate', 'violation_type', 
            'violation_type_name', 'timestamp', 'location', 'description',
            'evidence_image', 'evidence_image_url', 'detected_license_plate',
            'confidence_score', 'recorded_by', 'status', 'payment_status',
            'created_at', 'updated_at'
        ]
        read_only_fields = [
            'id', 'timestamp', 'detected_license_plate', 'confidence_score',
            'created_at', 'updated_at', 'payment_status'
        ]
    
    def get_violation_type_name(self, obj):
        return obj.violation_type.name
    
    def get_vehicle_license_plate(self, obj):
        return obj.vehicle.license_plate
    
    def get_evidence_image_url(self, obj):
        if obj.evidence_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.evidence_image.url)
            return obj.evidence_image.url
        return None
    
    def get_payment_status(self, obj):
        try:
            payment = obj.payment
            return payment.status
        except:
            return None

class PaymentSerializer(serializers.ModelSerializer):
    violation_details = serializers.SerializerMethodField()
    
    class Meta:
        model = Payment
        fields = [
            'id', 'violation', 'violation_details', 'amount', 'timestamp',
            'transaction_id', 'status', 'payment_method', 'payment_details'
        ]
        read_only_fields = ['id', 'timestamp', 'transaction_id']
    
    def get_violation_details(self, obj):
        return {
            'id': str(obj.violation.id),
            'type': obj.violation.violation_type.name,
            'vehicle': obj.violation.vehicle.license_plate,
            'date': obj.violation.timestamp
        }

class NotificationSerializer(serializers.ModelSerializer):
    violation_details = serializers.SerializerMethodField()
    
    class Meta:
        model = Notification
        fields = [
            'id', 'user', 'title', 'message', 'violation', 
            'violation_details', 'timestamp', 'is_read'
        ]
        read_only_fields = ['id', 'user', 'timestamp']
    
    def get_violation_details(self, obj):
        if obj.violation:
            return {
                'id': str(obj.violation.id),
                'type': obj.violation.violation_type.name,
                'vehicle': obj.violation.vehicle.license_plate,
                'status': obj.violation.status
            }
        return None

class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    user_type = serializers.ChoiceField(choices=['vehicle_owner', 'traffic_officer'])
    
    # Additional fields for VehicleOwner
    citizenship_number = serializers.CharField(required=False)
    phone_number = serializers.CharField(required=False)
    address = serializers.CharField(required=False)
    
    # Additional fields for TrafficOfficer
    badge_number = serializers.CharField(required=False)
    department = serializers.CharField(required=False)
    jurisdiction = serializers.CharField(required=False)
    
    class Meta:
        model = User
        fields = [
            'username', 'password', 'email', 'first_name', 'last_name', 'user_type',
            'citizenship_number', 'phone_number', 'address',
            'badge_number', 'department', 'jurisdiction'
        ]
    
    def validate(self, data):
        user_type = data.get('user_type')
        
        # Validate VehicleOwner fields
        if user_type == 'vehicle_owner':
            if not all(data.get(field) for field in ['citizenship_number', 'phone_number', 'address']):
                raise serializers.ValidationError("Citizenship number, phone number, and address are required for vehicle owners")
        
        # Validate TrafficOfficer fields
        elif user_type == 'traffic_officer':
            if not all(data.get(field) for field in ['badge_number', 'department']):
                raise serializers.ValidationError("Badge number and department are required for traffic officers")
        
        return data
    
    def create(self, validated_data):
        user_type = validated_data.pop('user_type')
        
        # Extract role-specific fields
        vehicle_owner_fields = {
            'citizenship_number': validated_data.pop('citizenship_number', None),
            'phone_number': validated_data.pop('phone_number', None),
            'address': validated_data.pop('address', None)
        }
        
        traffic_officer_fields = {
            'badge_number': validated_data.pop('badge_number', None),
            'department': validated_data.pop('department', None),
            'jurisdiction': validated_data.pop('jurisdiction', None)
        }
        
        # Create user
        password = validated_data.pop('password')
        user = User.objects.create(**validated_data)
        user.set_password(password)
        user.save()
        
        # Create profile
        profile = Profile.objects.create(user=user)
        
        # Create role-specific model
        if user_type == 'vehicle_owner':
            VehicleOwner.objects.create(profile=profile, **vehicle_owner_fields)
        elif user_type == 'traffic_officer':
            TrafficOfficer.objects.create(profile=profile, **traffic_officer_fields)
        
        return user
