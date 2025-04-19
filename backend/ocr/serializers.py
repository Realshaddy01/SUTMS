from rest_framework import serializers

class LicensePlateDetectionSerializer(serializers.Serializer):
    image = serializers.ImageField(help_text="The image file containing the license plate")
    
    class Meta:
        swagger_schema_fields = {
            "description": "Upload an image for license plate detection"
        }

class VehicleInfoSerializer(serializers.Serializer):
    license_plate = serializers.CharField(help_text="The detected license plate number")
    vehicle_type = serializers.CharField(read_only=True, help_text="Type of vehicle")
    owner_name = serializers.CharField(read_only=True, help_text="Name of the vehicle owner")
    registration_date = serializers.DateField(read_only=True, help_text="Vehicle registration date")
    status = serializers.CharField(read_only=True, help_text="Current vehicle status")

class DetectionResponseSerializer(serializers.Serializer):
    success = serializers.BooleanField(help_text="Whether the detection was successful")
    license_plate = serializers.CharField(help_text="The detected license plate number")
    confidence = serializers.FloatField(help_text="Confidence score of the detection")
    vehicle_info = VehicleInfoSerializer(help_text="Vehicle information if available")
    bbox = serializers.ListField(
        child=serializers.IntegerField(),
        help_text="Bounding box coordinates [x1, y1, x2, y2]"
    ) 