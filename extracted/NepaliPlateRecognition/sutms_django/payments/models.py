"""
Models for the payments app.
"""
import uuid
import json
from django.db import models
from django.conf import settings
from django.utils.translation import gettext_lazy as _
from django.utils import timezone


class Payment(models.Model):
    """
    Payment model for traffic violation payments.
    """
    class PaymentMethod(models.TextChoices):
        """Payment method choices."""
        STRIPE = 'stripe', _('Credit/Debit Card (Stripe)')
        KHALTI = 'khalti', _('Khalti')
        ESEWA = 'esewa', _('eSewa')
        BANK_TRANSFER = 'bank_transfer', _('Bank Transfer')
        CASH = 'cash', _('Cash')
        OTHER = 'other', _('Other')
    
    class PaymentStatus(models.TextChoices):
        """Payment status choices."""
        PENDING = 'pending', _('Pending')
        COMPLETED = 'completed', _('Completed')
        CANCELLED = 'cancelled', _('Cancelled')
        FAILED = 'failed', _('Failed')
        REFUNDED = 'refunded', _('Refunded')
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    violation = models.ForeignKey('violations.Violation', on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(_('amount'), max_digits=10, decimal_places=2)
    payment_method = models.CharField(
        _('payment method'),
        max_length=20,
        choices=PaymentMethod.choices,
        default=PaymentMethod.STRIPE
    )
    status = models.CharField(
        _('status'),
        max_length=20,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING
    )
    transaction_id = models.CharField(_('transaction ID'), max_length=255, blank=True)
    receipt_number = models.CharField(_('receipt number'), max_length=50, blank=True)
    receipt_url = models.URLField(_('receipt URL'), blank=True)
    
    # Stripe specific fields
    stripe_session_id = models.CharField(_('Stripe session ID'), max_length=255, blank=True)
    stripe_payment_intent_id = models.CharField(_('Stripe payment intent ID'), max_length=255, blank=True)
    
    # Other payment gateways
    khalti_token = models.CharField(_('Khalti token'), max_length=255, blank=True)
    esewa_reference_id = models.CharField(_('eSewa reference ID'), max_length=255, blank=True)
    
    # Payment details
    paid_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='payments_made'
    )
    payment_date = models.DateTimeField(_('payment date'), null=True, blank=True)
    due_date = models.DateTimeField(_('due date'), null=True, blank=True)
    
    # Administrative fields
    processed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='payments_processed'
    )
    notes = models.TextField(_('notes'), blank=True)
    created_at = models.DateTimeField(_('created at'), auto_now_add=True)
    updated_at = models.DateTimeField(_('updated at'), auto_now=True)
    
    class Meta:
        verbose_name = _('payment')
        verbose_name_plural = _('payments')
        ordering = ['-created_at']
    
    def __str__(self):
        """String representation of the payment."""
        return f"Payment {self.id} - {self.get_status_display()} - {self.amount}"
    
    @property
    def is_paid(self):
        """Check if the payment is completed."""
        return self.status == self.PaymentStatus.COMPLETED
    
    @property
    def is_overdue(self):
        """Check if the payment is overdue."""
        if not self.due_date:
            return False
        return self.due_date < timezone.now() and self.status == self.PaymentStatus.PENDING
    
    def mark_as_completed(self, transaction_id=None, processed_by=None):
        """Mark the payment as completed."""
        self.status = self.PaymentStatus.COMPLETED
        self.payment_date = timezone.now()
        
        if transaction_id:
            self.transaction_id = transaction_id
            
        if processed_by:
            self.processed_by = processed_by
            
        self.save()


class PaymentLog(models.Model):
    """
    Payment log model for tracking payment events.
    """
    class LogType(models.TextChoices):
        """Log type choices."""
        INFO = 'info', _('Information')
        SUCCESS = 'success', _('Success')
        FAILURE = 'failure', _('Failure')
        REFUND = 'refund', _('Refund')
        ERROR = 'error', _('Error')
        WARNING = 'warning', _('Warning')
    
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    payment = models.ForeignKey(Payment, on_delete=models.CASCADE, related_name='logs')
    type = models.CharField(
        _('log type'),
        max_length=20,
        choices=LogType.choices,
        default=LogType.INFO
    )
    message = models.TextField(_('message'))
    data = models.JSONField(_('data'), default=dict, blank=True)
    created_at = models.DateTimeField(_('created at'), auto_now_add=True)
    
    class Meta:
        verbose_name = _('payment log')
        verbose_name_plural = _('payment logs')
        ordering = ['-created_at']
    
    def __str__(self):
        """String representation of the payment log."""
        return f"{self.get_type_display()} - {self.payment_id} - {self.created_at}"
    
    def get_data_pretty(self):
        """Get the data formatted as pretty JSON."""
        if isinstance(self.data, dict):
            return json.dumps(self.data, indent=2)
        return str(self.data)


class PaymentReceipt(models.Model):
    """
    Payment receipt model for storing receipts.
    """
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    payment = models.OneToOneField(Payment, on_delete=models.CASCADE, related_name='receipt')
    receipt_number = models.CharField(_('receipt number'), max_length=50)
    receipt_data = models.JSONField(_('receipt data'), default=dict)
    pdf_file = models.FileField(_('PDF file'), upload_to='receipts/', blank=True, null=True)
    generated_at = models.DateTimeField(_('generated at'), auto_now_add=True)
    
    class Meta:
        verbose_name = _('payment receipt')
        verbose_name_plural = _('payment receipts')
        ordering = ['-generated_at']
    
    def __str__(self):
        """String representation of the payment receipt."""
        return f"Receipt {self.receipt_number} - {self.payment_id}"
    
    def get_receipt_data_pretty(self):
        """Get the receipt data formatted as pretty JSON."""
        if isinstance(self.receipt_data, dict):
            return json.dumps(self.receipt_data, indent=2)
        return str(self.receipt_data)