from django.db import models
from django.conf import settings

# Create your models here.

class ViolationType(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField()
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2)
    points = models.IntegerField(default=0)
    
    def __str__(self):
        return self.name

class Violation(models.Model):
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('paid', 'Paid'),
        ('appealed', 'Appealed'),
        ('cancelled', 'Cancelled'),
    ]
    
    vehicle = models.ForeignKey('vehicles.Vehicle', on_delete=models.CASCADE)
    violation_type = models.ForeignKey(ViolationType, on_delete=models.PROTECT)
    date = models.DateTimeField(auto_now_add=True)
    location = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    evidence_image = models.ImageField(upload_to='violations/evidence/', null=True, blank=True)
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    reported_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True)
    
    def __str__(self):
        return f"{self.vehicle.license_plate} - {self.violation_type.name} ({self.date})"
