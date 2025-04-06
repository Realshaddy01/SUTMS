"""
Admin interface for the OCR application.
"""
from django.contrib import admin
from django.utils.html import format_html
from django.utils.translation import gettext_lazy as _

from .models import LicensePlateDetection, OCRModel


@admin.register(LicensePlateDetection)
class LicensePlateDetectionAdmin(admin.ModelAdmin):
    """Admin interface for license plate detections."""
    list_display = (
        'id', 'display_text', 'status', 'created_at', 'view_image'
    )
    list_filter = ('status', 'is_in_training_set', 'created_at')
    search_fields = ('detected_text', 'corrected_text')
    readonly_fields = ('processing_time_ms', 'created_at', 'updated_at')
    # Removed autocomplete_fields to fix the error
    fieldsets = (
        (None, {
            'fields': ('status', 'is_in_training_set')
        }),
        (_('Detection Results'), {
            'fields': (
                'detected_text', 'corrected_text', 'confidence',
                'processing_time_ms'
            )
        }),
        (_('Images'), {
            'fields': ('original_image', 'cropped_plate')
        }),
        (_('Location'), {
            'fields': ('latitude', 'longitude', 'location_name'),
            'classes': ('collapse',)
        }),
        (_('Timestamps'), {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    
    def view_image(self, obj):
        """Display a thumbnail of the detection image."""
        if obj.original_image:
            return format_html(
                '<a href="{}" target="_blank"><img src="{}" width="50" height="30" /></a>',
                obj.original_image.url, obj.original_image.url
            )
        return '-'
    
    view_image.short_description = _('Image')
    
    def has_vehicle(self, obj):
        """Check if the detection has a matched vehicle."""
        return bool(obj.matched_vehicle)
    
    has_vehicle.boolean = True
    has_vehicle.short_description = _('Has Vehicle')
    
    def display_text(self, obj):
        """Display the license plate text."""
        if obj.corrected_text:
            return f"{obj.corrected_text} (corrected)"
        return obj.detected_text or '-'
    
    display_text.short_description = _('License Plate')


@admin.register(OCRModel)
class OCRModelAdmin(admin.ModelAdmin):
    """Admin interface for OCR models."""
    list_display = (
        'name', 'version', 'model_type', 'is_active', 
        'accuracy', 'created_at'
    )
    list_filter = ('model_type', 'is_active', 'created_at')
    search_fields = ('name', 'version', 'description')
    readonly_fields = ('created_at', 'last_used')
    # Removed autocomplete_fields to fix the error
    fieldsets = (
        (None, {
            'fields': ('name', 'version', 'model_type', 'is_active')
        }),
        (_('Model Details'), {
            'fields': ('description', 'file_path', 'accuracy')
        }),
        (_('Metadata'), {
            'fields': ('created_at', 'last_used'),
            'classes': ('collapse',)
        }),
    )