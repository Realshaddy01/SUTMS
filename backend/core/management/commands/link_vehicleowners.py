from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from vehicles.models import VehicleOwner
from django.db import transaction

User = get_user_model()

class Command(BaseCommand):
    help = 'Links VehicleOwner objects with User objects based on matching email addresses'

    def handle(self, *args, **options):
        self.stdout.write('Starting to link VehicleOwner objects with User objects...')
        
        try:
            with transaction.atomic():
                # Get all VehicleOwner objects
                vehicle_owners = VehicleOwner.objects.all()
                self.stdout.write(f'Found {len(vehicle_owners)} VehicleOwner objects')
                
                # Get all vehicle owner users
                vehicle_owner_users = User.objects.filter(user_type='vehicle_owner')
                self.stdout.write(f'Found {len(vehicle_owner_users)} vehicle owner users')
                
                # Count of linked vehicle owners
                linked_count = 0
                
                # Link VehicleOwner objects with User objects
                for vehicle_owner in vehicle_owners:
                    # Try to find a matching user by email
                    try:
                        user = User.objects.get(email=vehicle_owner.email)
                        vehicle_owner.user = user
                        vehicle_owner.save()
                        self.stdout.write(f'Linked VehicleOwner {vehicle_owner.name} with User {user.username}')
                        linked_count += 1
                    except User.DoesNotExist:
                        self.stdout.write(self.style.WARNING(f'No matching user found for VehicleOwner {vehicle_owner.name} with email {vehicle_owner.email}'))
                
                self.stdout.write(self.style.SUCCESS(f'Successfully linked {linked_count} VehicleOwner objects with User objects'))
        
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error linking VehicleOwner objects: {str(e)}')) 