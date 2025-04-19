from django.contrib import admin
from .models import ViolationType, Violation, ViolationAppeal, Notification

@admin.register(ViolationType)
class ViolationTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'fine_amount', 'description', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('name', 'description')

@admin.register(Violation)
class ViolationAdmin(admin.ModelAdmin):
    list_display = ('vehicle', 'violation_type', 'violation_date', 'status', 'fine_amount', 'paid_amount')
    list_filter = ('status', 'violation_date', 'created_at')
    search_fields = ('vehicle__license_plate', 'violation_type__name', 'location')
    date_hierarchy = 'violation_date'

@admin.register(ViolationAppeal)
class ViolationAppealAdmin(admin.ModelAdmin):
    list_display = ('violation', 'appealed_by', 'status', 'created_at')
    list_filter = ('status', 'created_at')
    search_fields = ('violation__vehicle__license_plate', 'reason', 'review_notes')
    date_hierarchy = 'created_at'

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('user', 'title', 'notification_type', 'is_read', 'created_at')
    list_filter = ('notification_type', 'is_read', 'created_at')
    search_fields = ('user__username', 'title', 'message')
    date_hierarchy = 'created_at'
