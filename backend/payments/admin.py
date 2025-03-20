from django.contrib import admin
from .models import Payment

@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = ('id', 'violation', 'user', 'amount', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('violation__vehicle__license_plate', 'payment_intent_id')
    readonly_fields = ('payment_intent_id', 'created_at', 'updated_at')

