"""
Admin configuration for the cameras app.
"""

from django.contrib import admin
from django.utils.html import format_html
from .models import TrafficCamera, CameraCapture

@admin.register(TrafficCamera)
class TrafficCameraAdmin(admin.ModelAdmin):
    """Admin interface for TrafficCamera model."""
    list_display = ('camera_id', 'name', 'location', 'status', 'is_active', 'last_capture_time')
    list_filter = ('status', 'is_active')
    search_fields = ('camera_id', 'name', 'location')
    readonly_fields = ('status', 'last_capture_time', 'error_message', 'created_at', 'updated_at')
    fieldsets = (
        (None, {
            'fields': ('camera_id', 'name', 'location', 'is_active')
        }),
        ('Connection Details', {
            'fields': ('url', 'auth_token', 'capture_interval')
        }),
        ('Location', {
            'fields': ('latitude', 'longitude')
        }),
        ('Status', {
            'fields': ('status', 'last_capture_time', 'error_message')
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        })
    )

@admin.register(CameraCapture)
class CameraCaptureAdmin(admin.ModelAdmin):
    """Admin interface for CameraCapture model."""
    list_display = ('id', 'camera', 'timestamp', 'processed', 'thumbnail_preview', 'plate_detected', 'detected_plate_text', 'confidence')
    list_filter = ('camera', 'processed', 'plate_detected')
    search_fields = ('camera__name', 'detected_plate_text')
    readonly_fields = ('timestamp', 'detection_time', 'image_preview')
    
    def thumbnail_preview(self, obj):
        """Display thumbnail preview of the captured image."""
        if obj.image:
            return format_html('<img src="{}" style="max-height: 50px; max-width: 100px;" />', obj.image.url)
        return "-"
    thumbnail_preview.short_description = 'Preview'
    
    def image_preview(self, obj):
        """Display larger preview of the captured image."""
        if obj.image:
            return format_html('<img src="{}" style="max-height: 300px; max-width: 600px;" />', obj.image.url)
        return "-"
    image_preview.short_description = 'Image Preview'