from django.db import models
from django.conf import settings
from vehicles.models import Vehicle

class ViolationType(models.Model):
    name = models.CharField(max_length=100)
    description = models.TextField()
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2)
    penalty_points = models.PositiveIntegerField(default=0)
    
    def __str__(self):
        return self.name

class Violation(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('disputed', 'Disputed'),
        ('resolved', 'Resolved'),
        ('cancelled', 'Cancelled'),
    )
    
    vehicle = models.ForeignKey(Vehicle, on_delete=models.CASCADE, related_name='violations')
    violation_type = models.ForeignKey(ViolationType, on_delete=models.CASCADE)
    reported_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='reported_violations')
    location = models.CharField(max_length=255)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    timestamp = models.DateTimeField(auto_now_add=True)
    description = models.TextField()
    evidence_image = models.ImageField(upload_to='violation_evidence/', null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    fine_amount = models.DecimalField(max_digits=10, decimal_places=2)
    is_paid = models.BooleanField(default=False)
    payment_date = models.DateTimeField(null=True, blank=True)
    
    def __str__(self):
        return f"{self.vehicle.license_plate} - {self.violation_type.name} - {self.timestamp.date()}"

class ViolationAppeal(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )
    
    violation = models.ForeignKey(Violation, on_delete=models.CASCADE, related_name='appeals')
    submitted_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE)
    reason = models.TextField()
    evidence_image = models.ImageField(upload_to='appeal_evidence/', null=True, blank=True)
    submitted_at = models.DateTimeField(auto_now_add=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='pending')
    reviewed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='reviewed_appeals')
    reviewed_at = models.DateTimeField(null=True, blank=True)
    reviewer_comments = models.TextField(null=True, blank=True)
    
    def __str__(self):
        return f"Appeal for {self.violation} - {self.get_status_display()}"

