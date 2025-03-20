from django.contrib import admin
from .models import DetectionModel, DetectionResult

@admin.register(DetectionModel)
class DetectionModelAdmin(admin.ModelAdmin):
    list_display = ('name', 'model_type', 'version', 'accuracy', 'is_active')
    list_filter = ('model_type', 'is_active')
    search_fields = ('name', 'description')

@admin.register(DetectionResult)
class DetectionResultAdmin(admin.ModelAdmin):
    list_display = ('id', 'detection_model', 'number_plate', 'confidence', 'created_at')
    list_filter = ('detection_model__model_type',)
    search_fields = ('number_plate',)
    readonly_fields = ('created_at',)

