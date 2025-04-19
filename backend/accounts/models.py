"""
Models for the accounts app.
"""
from django.db import models
from django.contrib.auth.models import AbstractUser
try:
    from django.utils.translation import gettext_lazy as _
except ImportError:
    # Django 5.0+ compatibility
    from django.utils.translation import gettext_lazy as _


class User(AbstractUser):
    """Custom user model for the SUTMS application."""
    
    USER_TYPE_CHOICES = (
        ('vehicle_owner', 'Vehicle Owner'),
        ('traffic_officer', 'Traffic Officer'),
        ('admin', 'Administrator'),
    )
    
    email = models.EmailField(_('email address'), unique=True)
    user_type = models.CharField(max_length=20, choices=USER_TYPE_CHOICES, default='vehicle_owner')
    phone_number = models.CharField(max_length=15, blank=True, null=True)
    profile_picture = models.ImageField(_('profile picture'), upload_to='profile_pictures', null=True, blank=True)
    address = models.TextField(_('address'), blank=True)
    badge_number = models.CharField(_('badge number'), max_length=50, blank=True)
    fcm_token = models.CharField(_('FCM token'), max_length=255, blank=True)
    
    @property
    def profile_pic(self):
        return self.profile_picture
        
    @profile_pic.setter
    def profile_pic(self, value):
        self.profile_picture = value
    
    def is_admin(self):
        return self.user_type == 'admin'
    
    def is_officer(self):
        return self.user_type == 'traffic_officer'
    
    def is_vehicle_owner(self):
        return self.user_type == 'vehicle_owner'
    
    def get_full_name(self):
        return f"{self.first_name} {self.last_name}"
    
    def __str__(self):
        """String representation of the user."""
        return self.username
    
    class Meta:
        verbose_name = _('user')
        verbose_name_plural = _('users')


class UserProfile(models.Model):
    """Additional user profile information."""
    
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='profile')
    bio = models.TextField(_('bio'), blank=True)
    date_of_birth = models.DateField(_('date of birth'), null=True, blank=True)
    emergency_contact = models.CharField(_('emergency contact'), max_length=20, blank=True)
    emergency_contact_name = models.CharField(_('emergency contact name'), max_length=100, blank=True)
    is_verified = models.BooleanField(_('is verified'), default=False)
    
    class Meta:
        verbose_name = _('user profile')
        verbose_name_plural = _('user profiles')
    
    def __str__(self):
        """String representation of the user profile."""
        return f"Profile for {self.user.get_full_name() or self.user.username}"

