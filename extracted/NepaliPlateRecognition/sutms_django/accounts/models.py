"""
Models for the accounts app.
"""
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils.translation import gettext_lazy as _


class User(AbstractUser):
    """Custom user model for the SUTMS application."""
    
    class UserType(models.TextChoices):
        """User types for role-based access control."""
        ADMIN = 'admin', _('Administrator')
        OFFICER = 'officer', _('Traffic Officer')
        VEHICLE_OWNER = 'vehicle_owner', _('Vehicle Owner')
    
    email = models.EmailField(_('email address'), unique=True)
    user_type = models.CharField(
        _('user type'),
        max_length=20,
        choices=UserType.choices,
        default=UserType.VEHICLE_OWNER
    )
    phone_number = models.CharField(_('phone number'), max_length=20, blank=True)
    profile_picture = models.ImageField(_('profile picture'), upload_to='profile_pictures', null=True, blank=True)
    address = models.TextField(_('address'), blank=True)
    badge_number = models.CharField(_('badge number'), max_length=50, blank=True)
    fcm_token = models.CharField(_('FCM token'), max_length=255, blank=True)
    
    def is_admin(self):
        """Check if the user is an administrator."""
        return self.user_type == self.UserType.ADMIN
    
    def is_officer(self):
        """Check if the user is a traffic officer."""
        return self.user_type == self.UserType.OFFICER
    
    def is_vehicle_owner(self):
        """Check if the user is a vehicle owner."""
        return self.user_type == self.UserType.VEHICLE_OWNER
    
    def __str__(self):
        """String representation of the user."""
        return f"{self.get_full_name() or self.username} ({self.get_user_type_display()})"
    
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