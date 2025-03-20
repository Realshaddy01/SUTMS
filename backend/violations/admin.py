from django.contrib import admin
from .models import ViolationType, Violation, ViolationAppeal

@admin.register(ViolationType)
class ViolationTypeAdmin(admin.ModelAdmin):
    list_display = ('name', 'fine_amount', 'penalty_points')
    search_fields = ('name', 'description')

class ViolationAppealInline(admin.TabularInline):
    model = ViolationAppeal
    extra = 0
    readonly_fields = ('submitted_by', 'submitted_at')

@admin.register(Violation)
class ViolationAdmin(admin.ModelAdmin):
    list_display = ('id', 'vehicle', 'violation_type', 'location', 'timestamp', 'status', 'is_paid')
    list_filter = ('status', 'is_paid', 'violation_type')
    search_fields = ('vehicle__license_plate', 'location', 'description')
    inlines = [ViolationAppealInline]
    date_hierarchy = 'timestamp'

@admin.register(ViolationAppeal)
class ViolationAppealAdmin(admin.ModelAdmin):
    list_display = ('violation', 'submitted_by', 'submitted_at', 'status')
    list_filter = ('status',)
    search_fields = ('violation__vehicle__license_plate', 'reason')
    readonly_fields = ('submitted_by', 'submitted_at')

