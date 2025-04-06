from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from django.contrib.auth.models import User
from .models import (
    Profile, Vehicle, VehicleOwner, TrafficOfficer, 
    Violation, ViolationType, Payment, Notification
)

# Register User with Profile inline
class ProfileInline(admin.StackedInline):
    model = Profile
    can_delete = False
    verbose_name_plural = 'Profile'

class CustomUserAdmin(UserAdmin):
    inlines = (ProfileInline,)
    list_display = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'get_user_type')
    
    def get_user_type(self, obj):
        try:
            if hasattr(obj.profile, 'vehicleowner'):
                return 'Vehicle Owner'
            elif hasattr(obj.profile, 'trafficofficer'):
                return 'Traffic Officer'
            return 'N/A'
        except Profile.DoesNotExist:
            return 'N/A'
    get_user_type.short_description = 'User Type'

admin.site.unregister(User)
admin.site.register(User, CustomUserAdmin)

# Register Vehicle models
@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = ('license_plate', 'owner', 'model', 'color', 'year')
    search_fields = ('license_plate', 'owner__user__username', 'model')
    list_filter = ('year', 'color')

# Register Vehicle Owner model
@admin.register(VehicleOwner)
class VehicleOwnerAdmin(admin.ModelAdmin):
    list_display = ('user', 'phone_number', 'address')
    search_fields = ('user__username', 'user__email', 'phone_number')

# Register Traffic Officer model
@admin.register(TrafficOfficer)
class TrafficOfficerAdmin(admin.ModelAdmin):
    list_display = ('user', 'badge_number', 'department')
    search_fields = ('user__username', 'user__email', 'badge_number')
    list_filter = ('department',)

# Register Violation Type model
@admin.register(ViolationType)
class ViolationTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'description', 'fine_amount')
    search_fields = ('name', 'description')

# Register Violation model
@admin.register(Violation)
class ViolationAdmin(admin.ModelAdmin):
    list_display = ('id', 'vehicle', 'violation_type', 'timestamp', 'location', 'status')
    search_fields = ('vehicle__license_plate', 'location')
    list_filter = ('status', 'violation_type', 'timestamp')
    readonly_fields = ('evidence_image',)

# Register Payment model
@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ('id', 'violation', 'amount', 'timestamp', 'status', 'payment_method')
    search_fields = ('violation__vehicle__license_plate',)
    list_filter = ('status', 'payment_method', 'timestamp')

# Register Notification model
@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'title', 'timestamp', 'is_read')
    search_fields = ('user__username', 'title', 'message')
    list_filter = ('is_read', 'timestamp')
