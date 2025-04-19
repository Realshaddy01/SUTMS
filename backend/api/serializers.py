from rest_framework import serializers
from django.contrib.auth import get_user_model
from accounts.models import UserProfile
from vehicles.models import Vehicle, VehicleDocument
from violations.models import Violation, ViolationType, ViolationAppeal, Notification
from payments.models import Payment, PaymentReceipt

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)
    first_name = serializers.CharField(required=True)
    last_name = serializers.CharField(required=True)
    user_type = serializers.ChoiceField(choices=User.USER_TYPE_CHOICES, default='vehicle_owner')

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'confirm_password', 
                 'first_name', 'last_name', 'phone_number', 'user_type',
                 'address', 'badge_number']

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError("Passwords do not match")
        return data

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        password = validated_data.pop('password')
        user = User.objects.create(**validated_data)
        user.set_password(password)
        user.save()
        return user


class UserProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserProfile
        fields = ['address', 'city', 'state', 'postal_code', 'bio', 'badge_number', 'department']


class UserSerializer(serializers.ModelSerializer):
    profile = UserProfileSerializer(required=False)
    full_name = serializers.SerializerMethodField()
    
    class Meta:
        model = User
        fields = ['id', 'email', 'username', 'first_name', 'last_name', 'full_name', 
                 'phone_number', 'user_type', 'profile_picture', 'date_joined', 'profile', 
                 'address', 'badge_number']
        read_only_fields = ['id', 'email', 'date_joined', 'full_name']
    
    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip()
        
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
        return obj.owner.get_full_name() if obj.owner else None


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
        fields = ['id', 'name', 'code', 'description', 'is_active', 'fine_amount', 'penalty_points']


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
        return obj.reported_by.get_full_name() if obj.reported_by else None


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
        return obj.paid_by.get_full_name() if obj.paid_by else None


class PaymentReceiptSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentReceipt
        fields = ['id', 'payment', 'receipt_number', 'receipt_data', 'pdf_file', 'generated_at']
        read_only_fields = ['id', 'generated_at']


class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for the Notification model."""
    class Meta:
        model = Notification
        fields = ['id', 'title', 'message', 'notification_type', 'is_read', 
                 'created_at', 'link', 'related_violation']
        read_only_fields = ['created_at']