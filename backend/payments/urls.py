"""
URL patterns for the payments app.
"""
from django.urls import path

from . import views

app_name = 'payments'

urlpatterns = [
    # Web views
    path('', views.payment_dashboard, name='dashboard'),
    path('list/', views.payment_list, name='payment_list'),
    path('<uuid:payment_id>/', views.payment_detail, name='payment_detail'),
    path('violation/<uuid:violation_id>/pay/', views.pay_violation, name='pay_violation'),
    path('<uuid:payment_id>/bank-transfer/', views.payment_bank_transfer, name='payment_bank_transfer'),
    path('<uuid:payment_id>/receipt/', views.payment_receipt, name='payment_receipt'),
    path('<uuid:payment_id>/mark-completed/', views.mark_payment_as_completed, name='mark_payment_completed'),
    path('success/', views.payment_success, name='payment_success'),
    path('cancel/', views.payment_cancel, name='payment_cancel'),
    
    # Webhook
    path('webhook/stripe/', views.stripe_webhook, name='stripe_webhook'),
    
    # API
    path('api/<uuid:payment_id>/status/', views.payment_status_api, name='payment_status_api'),
]