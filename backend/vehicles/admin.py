from django.contrib import admin
from .models import Vehicle, VehicleDocument

class VehicleDocumentInline(admin.TabularInline):
    model = VehicleDocument
    extra = 1

@admin.register(Vehicle)
class VehicleAdmin(admin.ModelAdmin):
    list_display = ('license_plate', 'owner', 'make', 'model', 'year', 'vehicle_type')
    list_filter = ('vehicle_type', 'year')
    search_fields = ('license_plate', 'registration_number', 'owner__username')
    inlines = [VehicleDocumentInline]

@admin.register(VehicleDocument)
class VehicleDocumentAdmin(admin.ModelAdmin):
    list_display = ('vehicle', 'document_type', 'document_number', 'expiry_date', 'is_verified')
    list_filter = ('document_type', 'is_verified')
    search_fields = ('vehicle__license_plate', 'document_number')

