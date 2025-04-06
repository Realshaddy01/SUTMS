from rest_framework import serializers
from django.contrib.auth import get_user_model
from accounts.models import UserProfile
from vehicles.models import Vehicle, VehicleDocument
from violations.models import Violation, ViolationType, ViolationAppeal
from payments.models import Payment, PaymentReceipt
from ocr.models import LicensePlateDetection, TrainingImage

User = get_user_model()


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['address', 'city', 'state', 'postal_code', 'bio', 'badge_number', 'department']


class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(required=False)
    
    class Meta:
        model = User
        fields = ['id', 'email', 'username', 'full_name', 'phone_number', 
                 'role', 'profile_image', 'date_joined', 'profile']
        read_only_fields = ['id', 'email', 'date_joined']
        
    def update(self, instance, validated_data):
        profile_data = validated_data.pop('profile', None)
        
        # Update user fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        
        # Update profile if provided
        if profile_data and hasattr(instance, 'profile'):
            for attr, value in profile_data.items():
                setattr(instance.profile, attr, value)
            instance.profile.save()
        
        return instance


class VehicleSerializer(serializers.ModelSerializer):
    owner_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Vehicle
        fields = ['id', 'license_plate', 'vehicle_type', 'make', 'model', 'color', 'year',
                 'registration_number', 'registration_date', 'registration_expiry',
                 'engine_number', 'chassis_number', 'insurance_provider', 
                 'insurance_policy_number', 'insurance_expiry', 'qr_code',
                 'owner', 'owner_name', 'created_at']
        read_only_fields = ['id', 'created_at', 'owner_name']
        
    def get_owner_name(self, obj):
        return obj.owner.full_name if obj.owner else None


class VehicleDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = VehicleDocument
        fields = ['id', 'vehicle', 'document_type', 'document_number',
                 'issue_date', 'expiry_date', 'document_file', 'is_verified',
                 'verification_date', 'verified_by', 'created_at']
        read_only_fields = ['id', 'is_verified', 'verification_date', 'verified_by', 'created_at']


class ViolationTypeSerializer(serializers.ModelSerializer):
    class Meta:
        model = ViolationType
        fields = ['id', 'name', 'description', 'code', 'fine_amount', 'penalty_points']


class ViolationSerializer(serializers.ModelSerializer):
    violation_type_details = ViolationTypeSerializer(source='violation_type', read_only=True)
    vehicle_details = VehicleSerializer(source='vehicle', read_only=True)
    reporter_name = serializers.SerializerMethodField()
    is_overdue = serializers.BooleanField(read_only=True)
    
    class Meta:
        model = Violation
        fields = ['id', 'violation_type', 'violation_type_details', 'vehicle', 'vehicle_details',
                 'reported_by', 'reporter_name', 'location', 'latitude', 'longitude',
                 'timestamp', 'description', 'evidence_image', 'status', 'fine_amount',
                 'due_date', 'is_overdue', 'created_at']
        read_only_fields = ['id', 'created_at', 'reporter_name', 'is_overdue']
        
    def get_reporter_name(self, obj):
        return obj.reported_by.full_name if obj.reported_by else None


class ViolationAppealSerializer(serializers.ModelSerializer):
    class Meta:
        model = ViolationAppeal
        fields = ['id', 'violation', 'appealed_by', 'reason', 'evidence_file',
                 'status', 'reviewed_by', 'review_date', 'review_notes', 'created_at']
        read_only_fields = ['id', 'created_at', 'reviewed_by', 'review_date']


class PaymentSerializer(serializers.ModelSerializer):
    violation_details = ViolationSerializer(source='violation', read_only=True)
    payer_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Payment
        fields = ['id', 'violation', 'violation_details', 'amount', 'payment_method',
                 'status', 'transaction_id', 'receipt_number', 'receipt_url',
                 'paid_by', 'payer_name', 'payment_date', 'stripe_payment_intent_id',
                 'stripe_session_id', 'notes', 'created_at']
        read_only_fields = ['id', 'created_at', 'payer_name', 'receipt_url']
        
    def get_payer_name(self, obj):
        return obj.paid_by.full_name if obj.paid_by else None


class PaymentReceiptSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentReceipt
        fields = ['id', 'payment', 'receipt_number', 'receipt_data', 'pdf_file', 'generated_at']
        read_only_fields = ['id', 'generated_at']


class LicensePlateDetectionSerializer(serializers.ModelSerializer):
    user_name = serializers.SerializerMethodField()
    vehicle_details = VehicleSerializer(source='matched_vehicle', read_only=True)
    
    class Meta:
        model = LicensePlateDetection
        fields = ['id', 'user', 'user_name', 'original_image', 'detected_plate_image',
                 'detected_text', 'confidence_score', 'matched_vehicle', 'vehicle_details',
                 'detected_at', 'latitude', 'longitude', 'location_name',
                 'detection_method', 'processing_time_ms']
        read_only_fields = ['id', 'detected_at', 'user_name']
        
    def get_user_name(self, obj):
        return obj.user.full_name if obj.user else None


class TrainingImageSerializer(serializers.ModelSerializer):
    class Meta:
        model = TrainingImage
        fields = ['id', 'image', 'license_plate_text', 'is_verified',
                 'verified_by', 'added_by', 'created_at']
        read_only_fields = ['id', 'created_at', 'verified_by', 'is_verified']