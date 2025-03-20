from django.db import models
from django.conf import settings

class Vehicle(models.Model):
    VEHICLE_TYPE_CHOICES = (
        ('car', 'Car'),
        ('motorcycle', 'Motorcycle'),
        ('truck', 'Truck'),
        ('bus', 'Bus'),
        ('other', 'Other'),
    )
    
    owner = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='vehicles')
    license_plate = models.CharField(max_length=20, unique=True)
    vehicle_type = models.CharField(max_length=15, choices=VEHICLE_TYPE_CHOICES)
    make = models.CharField(max_length=50)
    model = models.CharField(max_length=50)
    year = models.PositiveIntegerField()
    color = models.CharField(max_length=30)
    registration_number = models.CharField(max_length=50, unique=True)
    insurance_number = models.CharField(max_length=50, blank=True, null=True)
    insurance_expiry = models.DateField(blank=True, null=True)
    vehicle_image = models.ImageField(upload_to='vehicle_images/', blank=True, null=True)
    qr_code = models.ImageField(upload_to='vehicle_qr_codes/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    
    def __str__(self):
        return f"{self.license_plate} - {self.make} {self.model}"

class VehicleDocument(models.Model):
    DOCUMENT_TYPE_CHOICES = (
        ('registration', 'Registration Certificate'),
        ('insurance', 'Insurance Policy'),
        ('pollution', 'Pollution Certificate'),
        ('license', 'Driving License'),
        ('other', 'Other Document'),
    )
    
    vehicle = models.ForeignKey(Vehicle, on_delete=models.CASCADE, related_name='documents')
    document_type = models.CharField(max_length=20, choices=DOCUMENT_TYPE_CHOICES)
    document_number = models.CharField(max_length=50)
    issue_date = models.DateField()
    expiry_date = models.DateField()
    document_file = models.FileField(upload_to='vehicle_documents/')
    is_verified = models.BooleanField(default=False)
    
    def __str__(self):
        return f"{self.vehicle.license_plate} - {self.get_document_type_display()}"

