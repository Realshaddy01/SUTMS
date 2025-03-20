from rest_framework import serializers
from .models import Vehicle, VehicleDocument
import qrcode
from io import BytesIO
from django.core.files.base import ContentFile
import uuid

class VehicleDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = VehicleDocument
        fields = '__all__'
        read_only_fields = ['is_verified']

class VehicleSerializer(serializers.ModelSerializer):
    documents = VehicleDocumentSerializer(many=True, read_only=True)
    
    class Meta:
        model = Vehicle
        fields = '__all__'
        read_only_fields = ['owner', 'qr_code']
    
    def create(self, validated_data):
        user = self.context['request'].user
        vehicle = Vehicle.objects.create(owner=user, **validated_data)
        
        # Generate QR code
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(f"SUTMS-VEHICLE-{vehicle.id}-{vehicle.license_plate}-{uuid.uuid4()}")
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Save QR code
        buffer = BytesIO()
        img.save(buffer)
        filename = f'vehicle_qr_{vehicle.license_plate}.png'
        vehicle.qr_code.save(filename, ContentFile(buffer.getvalue()))
        
        return vehicle

