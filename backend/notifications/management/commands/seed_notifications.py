from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from vehicles.models import Vehicle, Violation
from notifications.models import Notification
from django.utils import timezone
import random
from datetime import datetime, timedelta

class Command(BaseCommand):
    help = 'Seeds the database with mock notifications'

    def handle(self, *args, **kwargs):
        self.stdout.write('Starting to seed mock notifications...')
        
        # Get all vehicles and violations
        vehicles = Vehicle.objects.all()
        violations = Violation.objects.all()
        
        # Create notifications for each vehicle
        for vehicle in vehicles:
            # Create registration expiry notification
            if vehicle.registration_expiry:
                days_until_expiry = (vehicle.registration_expiry - timezone.now()).days
                if days_until_expiry <= 30:
                    Notification.objects.create(
                        user=vehicle.owner.user,
                        title='Registration Expiry Alert',
                        message=f'Your vehicle registration (Ba {vehicle.license_plate}) will expire in {days_until_expiry} days.',
                        notification_type='warning',
                        related_model='vehicle',
                        related_id=vehicle.id
                    )
            
            # Create insurance expiry notification
            if vehicle.insurance_expiry:
                days_until_expiry = (vehicle.insurance_expiry - timezone.now()).days
                if days_until_expiry <= 30:
                    Notification.objects.create(
                        user=vehicle.owner.user,
                        title='Insurance Expiry Alert',
                        message=f'Your vehicle insurance (Ba {vehicle.license_plate}) will expire in {days_until_expiry} days.',
                        notification_type='warning',
                        related_model='vehicle',
                        related_id=vehicle.id
                    )
        
        # Create notifications for violations
        for violation in violations:
            if violation.status == 'pending':
                Notification.objects.create(
                    user=violation.vehicle.owner.user,
                    title='New Violation',
                    message=f'New violation detected for your vehicle (Ba {violation.vehicle.license_plate}): {violation.violation_type.description}',
                    notification_type='alert',
                    related_model='violation',
                    related_id=violation.id
                )
            elif violation.status == 'paid':
                Notification.objects.create(
                    user=violation.vehicle.owner.user,
                    title='Payment Confirmation',
                    message=f'Payment of NPR {violation.paid_amount} has been received for violation on {violation.violation_date.strftime("%Y-%m-%d")}',
                    notification_type='success',
                    related_model='violation',
                    related_id=violation.id
                )
        
        # Create some general notifications
        general_notifications = [
            ('System Update', 'The traffic management system has been updated with new features.', 'info'),
            ('Maintenance Notice', 'System maintenance scheduled for next week. Some services may be temporarily unavailable.', 'warning'),
            ('New Feature', 'QR code scanning feature is now available for quick vehicle verification.', 'success'),
            ('Traffic Alert', 'Heavy traffic expected in Kathmandu valley due to ongoing road construction.', 'alert'),
        ]
        
        for title, message, notification_type in general_notifications:
            Notification.objects.create(
                title=title,
                message=message,
                notification_type=notification_type,
                is_general=True
            )
        
        self.stdout.write(self.style.SUCCESS('Successfully seeded mock notifications!')) 