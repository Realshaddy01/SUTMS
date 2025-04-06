from django.db.models.signals import post_save
from django.dispatch import receiver
from django.contrib.auth.models import User
from .models import Profile, Violation, Payment, Notification
from .tasks import send_notification

@receiver(post_save, sender=User)
def create_user_profile(sender, instance, created, **kwargs):
    """Create a Profile instance when a new User is created."""
    if created:
        Profile.objects.create(user=instance)

@receiver(post_save, sender=Violation)
def create_payment_for_violation(sender, instance, created, **kwargs):
    """Create a Payment instance when a new Violation is confirmed."""
    if created or (instance.status == 'confirmed' and not hasattr(instance, 'payment')):
        Payment.objects.create(
            violation=instance,
            amount=instance.violation_type.fine_amount,
            status='pending',
            payment_method='credit_card'  # Default, will be updated during payment
        )

@receiver(post_save, sender=Violation)
def notify_status_change(sender, instance, created, **kwargs):
    """Send notification when violation status changes."""
    if not created and kwargs.get('update_fields'):
        if 'status' in kwargs.get('update_fields', []):
            # Send notification to vehicle owner
            owner = instance.vehicle.owner.profile.user
            
            status_messages = {
                'pending': 'A new violation has been recorded and is pending review.',
                'confirmed': 'A violation has been confirmed. Please check payment details.',
                'contested': 'Your contest request is under review.',
                'resolved': 'The violation has been resolved.',
                'cancelled': 'The violation has been cancelled.'
            }
            
            message = status_messages.get(
                instance.status, 
                f'The status of your violation has been updated to {instance.status}.'
            )
            
            notification_data = {
                'user_id': owner.id,
                'title': f'Violation Status Updated: {instance.status.title()}',
                'message': message,
                'violation_id': str(instance.id)
            }
            
            send_notification.delay(**notification_data)

@receiver(post_save, sender=Payment)
def notify_payment_status(sender, instance, created, **kwargs):
    """Send notification when payment status changes."""
    if not created and kwargs.get('update_fields'):
        if 'status' in kwargs.get('update_fields', []):
            # Send notification to vehicle owner
            owner = instance.violation.vehicle.owner.profile.user
            
            status_messages = {
                'pending': 'Your payment is pending processing.',
                'completed': 'Your payment has been successfully processed.',
                'failed': 'Your payment failed. Please try again.',
                'refunded': 'Your payment has been refunded.'
            }
            
            message = status_messages.get(
                instance.status, 
                f'The status of your payment has been updated to {instance.status}.'
            )
            
            notification_data = {
                'user_id': owner.id,
                'title': f'Payment Status: {instance.status.title()}',
                'message': message,
                'violation_id': str(instance.violation.id)
            }
            
            send_notification.delay(**notification_data)
