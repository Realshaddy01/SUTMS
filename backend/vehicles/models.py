"""
Models for the vehicles app.
"""
from django.db import models
from django.conf import settings
try:
    from django.utils.translation import gettext_lazy as _
except ImportError:
    # Django 5.0+ compatibility
    from django.utils.translation import gettext_lazy as _


class VehicleType(models.Model):
    """Types of vehicles such as car, motorcycle, truck, etc."""
    
    name = models.CharField(_('name'), max_length=100)
    code = models.CharField(_('code'), max_length=20, unique=True)
    description = models.TextField(_('description'), blank=True)
    is_active = models.BooleanField(_('is active'), default=True)
    
    class Meta:
        verbose_name = _('vehicle type')
        verbose_name_plural = _('vehicle types')
        ordering = ['name']
    
    def __str__(self):
        return self.name


class Vehicle(models.Model):
    """Vehicle model representing a registered vehicle in the system."""
    
    license_plate = models.CharField(_('license plate'), max_length=50, unique=True)
    nickname = models.CharField(_('nickname'), max_length=100, blank=True)
    vehicle_type = models.ForeignKey(
        VehicleType,
        on_delete=models.PROTECT,
        related_name='vehicles'
    )
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='owned_vehicles'
    )
    make = models.CharField(_('make'), max_length=100)
    model = models.CharField(_('model'), max_length=100)
    year = models.PositiveIntegerField(_('year'))
    color = models.CharField(_('color'), max_length=50)
    vin = models.CharField(_('VIN'), max_length=50, blank=True)
    registration_number = models.CharField(_('registration number'), max_length=50, blank=True)
    registration_expiry = models.DateField(_('registration expiry'), null=True, blank=True)
    is_insured = models.BooleanField(_('is insured'), default=False)
    insurance_provider = models.CharField(_('insurance provider'), max_length=100, blank=True)
    insurance_policy_number = models.CharField(_('insurance policy number'), max_length=100, blank=True)
    insurance_expiry = models.DateField(_('insurance expiry'), null=True, blank=True)
    is_active = models.BooleanField(_('is active'), default=True)
    registered_at = models.DateTimeField(_('registered at'), auto_now_add=True)
    
    class Meta:
        verbose_name = _('vehicle')
        verbose_name_plural = _('vehicles')
        ordering = ['-registered_at']
    
    def __str__(self):
        return f"{self.nickname or self.license_plate} ({self.make} {self.model}, {self.year})"
    
    qr_code = models.ImageField(_('QR code'), upload_to='vehicle_qrcodes', null=True, blank=True)
    
    @property
    def is_registration_expired(self):
        """Check if the registration has expired."""
        from django.utils import timezone
        if not self.registration_expiry:
            return False
        return self.registration_expiry < timezone.now().date()
    
    @property
    def is_insurance_expired(self):
        """Check if the insurance has expired."""
        from django.utils import timezone
        if not self.insurance_expiry:
            return True  # Consider expired if no expiry date
        return self.insurance_expiry < timezone.now().date()
    
    def generate_qr_code(self):
        """Generate a QR code for this vehicle and save it."""
        import qrcode
        import io
        from django.core.files.base import ContentFile
        
        # Create QR code data with vehicle details
        data = {
            'license_plate': self.license_plate,
            'registration_number': self.registration_number,
            'vehicle_id': self.id,
            'vehicle_type': self.vehicle_type.name,
            'make': self.make,
            'model': self.model,
            'year': self.year,
            'color': self.color
        }
        
        qr_data = f"SUTMS:{self.license_plate}:{self.id}"
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(qr_data)
        qr.make(fit=True)
        
        img = qr.make_image(fill_color="black", back_color="white")
        
        # Save the image to a BytesIO object
        buffer = io.BytesIO()
        img.save(buffer, format="PNG")
        buffer.seek(0)
        
        # Save the image to the model
        filename = f"qrcode_{self.license_plate.replace(' ', '_')}.png"
        self.qr_code.save(filename, ContentFile(buffer.read()), save=False)
        
        # Save the model
        self.save(update_fields=['qr_code'])
        
        return self.qr_code


class VehicleDocument(models.Model):
    """Documents associated with a vehicle, such as registration, insurance, etc."""
    
    class DocumentType(models.TextChoices):
        """Types of vehicle documents."""
        REGISTRATION = 'registration', _('Registration')
        INSURANCE = 'insurance', _('Insurance')
        EMISSION_TEST = 'emission_test', _('Emission Test')
        TAX_RECEIPT = 'tax_receipt', _('Tax Receipt')
        OTHER = 'other', _('Other')
    
    vehicle = models.ForeignKey(
        Vehicle,
        on_delete=models.CASCADE,
        related_name='documents'
    )
    document_type = models.CharField(
        _('document type'),
        max_length=20,
        choices=DocumentType.choices,
        default=DocumentType.OTHER
    )
    title = models.CharField(_('title'), max_length=100)
    description = models.TextField(_('description'), blank=True)
    document_file = models.FileField(_('document file'), upload_to='vehicle_documents')
    is_verified = models.BooleanField(_('is verified'), default=False)
    verified_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='verified_vehicle_documents'
    )
    verified_at = models.DateTimeField(_('verified at'), null=True, blank=True)
    expiry_date = models.DateField(_('expiry date'), null=True, blank=True)
    uploaded_at = models.DateTimeField(_('uploaded at'), auto_now_add=True)
    
    class Meta:
        verbose_name = _('vehicle document')
        verbose_name_plural = _('vehicle documents')
        ordering = ['-uploaded_at']
    
    def __str__(self):
        return f"{self.get_document_type_display()}: {self.title} ({self.vehicle.license_plate})"