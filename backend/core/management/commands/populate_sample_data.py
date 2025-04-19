import random
from datetime import datetime, timedelta
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from django.db import transaction
from django.conf import settings
import logging

# Initialize logger
logger = logging.getLogger(__name__)

# Get the User model
User = get_user_model()

# Try to import models, with fallbacks for errors
try:
    from vehicles.models import Vehicle, VehicleType, VehicleOwner
except ImportError:
    logger.warning("Could not import Vehicle models")
    Vehicle = None
    VehicleType = None
    VehicleOwner = None

try:
    from violations.models import Violation, ViolationType, ViolationAppeal, Notification
except ImportError:
    logger.warning("Could not import Violation models")
    Violation = None
    ViolationType = None
    ViolationAppeal = None
    Notification = None

class Command(BaseCommand):
    help = 'Populates the database with sample data'

    def handle(self, *args, **kwargs):
        self.stdout.write(self.style.SUCCESS('Starting to populate database with sample data...'))
        
        try:
            with transaction.atomic():
                # Create users
                users = self.create_users()
                
                # Create VehicleOwner objects for vehicle owner users
                vehicle_owners = self.create_vehicle_owners(users)
                
                if VehicleType:
                    # Create vehicle types
                    vehicle_types = self.create_vehicle_types()
                else:
                    self.stdout.write(self.style.WARNING('Skipping vehicle types due to model import issue'))
                    vehicle_types = []
                
                if Vehicle and VehicleType and len(vehicle_types) > 0 and len(vehicle_owners) > 0:
                    # Create vehicles for vehicle owners
                    vehicles = self.create_vehicles(vehicle_owners, vehicle_types)
                else:
                    self.stdout.write(self.style.WARNING('Skipping vehicles due to model import issue'))
                    vehicles = []
                
                if ViolationType:
                    # Create violation types
                    violation_types = self.create_violation_types()
                else:
                    self.stdout.write(self.style.WARNING('Skipping violation types due to model import issue'))
                    violation_types = []
                
                if Violation and ViolationType and len(violation_types) > 0 and len(vehicles) > 0:
                    # Create violations
                    violations = self.create_violations(users, vehicles, violation_types)
                else:
                    self.stdout.write(self.style.WARNING('Skipping violations due to model import issue'))
                    violations = []
                
                if ViolationAppeal and len(violations) > 0:
                    # Create violation appeals
                    appeals = self.create_violation_appeals(users, violations)
                else:
                    self.stdout.write(self.style.WARNING('Skipping violation appeals due to model import issue'))
                    appeals = []
                
                if Notification and len(users) > 0:
                    # Create notifications
                    if len(violations) > 0 and len(appeals) > 0:
                        notifications = self.create_notifications(users, violations, appeals)
                    else:
                        notifications = self.create_system_notifications(users)
                else:
                    self.stdout.write(self.style.WARNING('Skipping notifications due to model import issue'))
                    notifications = []
                
                self.stdout.write(self.style.SUCCESS('Successfully populated database with sample data!'))
                
                # Print summary
                self.stdout.write(self.style.SUCCESS(f'Created {len(users)} users'))
                self.stdout.write(self.style.SUCCESS(f'Created {len(vehicle_owners) if vehicle_owners else 0} vehicle owners'))
                self.stdout.write(self.style.SUCCESS(f'Created {len(vehicle_types) if vehicle_types else 0} vehicle types'))
                self.stdout.write(self.style.SUCCESS(f'Created {len(vehicles) if vehicles else 0} vehicles'))
                self.stdout.write(self.style.SUCCESS(f'Created {len(violation_types) if violation_types else 0} violation types'))
                self.stdout.write(self.style.SUCCESS(f'Created {len(violations) if violations else 0} violations'))
                self.stdout.write(self.style.SUCCESS(f'Created {len(appeals) if appeals else 0} violation appeals'))
                self.stdout.write(self.style.SUCCESS(f'Created {len(notifications) if notifications else 0} notifications'))
        
        except Exception as e:
            self.stdout.write(self.style.ERROR(f'Error populating database: {str(e)}'))
    
    def create_users(self):
        self.stdout.write('Creating users...')
        users = []
        
        # Create 2 vehicle owners
        for i in range(1, 3):
            user, created = User.objects.get_or_create(
                username=f'vehicleowner{i}',
                defaults={
                    'email': f'vehicleowner{i}@example.com',
                    'first_name': f'Vehicle Owner {i}',
                    'last_name': 'User',
                    'phone_number': f'+977 98{random.randint(10000000, 99999999)}',
                    'address': f'Test Address {i}, Kathmandu',
                    'user_type': 'vehicle_owner',
                }
            )
            if created:
                user.set_password('password@123')
                user.save()
                self.stdout.write(f'Created vehicle owner user: vehicleowner{i}')
            users.append(user)
        
        # Create 2 traffic officers
        for i in range(1, 3):
            user, created = User.objects.get_or_create(
                username=f'trafficuser{i}',
                defaults={
                    'email': f'trafficuser{i}@example.com',
                    'first_name': f'Traffic Officer {i}',
                    'last_name': 'User',
                    'phone_number': f'+977 98{random.randint(10000000, 99999999)}',
                    'badge_number': f'NEP-OFF-{1000+i}',
                    'address': f'Police Station {i}, Kathmandu',
                    'user_type': 'officer',
                }
            )
            if created:
                user.set_password('password@123')
                user.save()
                self.stdout.write(f'Created traffic officer user: trafficuser{i}')
            users.append(user)
            
        return users
    
    def create_vehicle_owners(self, users):
        self.stdout.write('Creating vehicle owners...')
        vehicle_owners = []
        
        # Filter vehicle owner users
        vehicle_owner_users = [user for user in users if user.user_type == 'vehicle_owner']
        
        # Create VehicleOwner instances
        for user in vehicle_owner_users:
            try:
                # Create or get VehicleOwner
                vehicle_owner, created = VehicleOwner.objects.get_or_create(
                    email=user.email,
                    defaults={
                        'name': f"{user.first_name} {user.last_name}",
                        'phone': user.phone_number,
                        'address': user.address,
                        'license_number': f"LIC-{random.randint(100000, 999999)}",
                    }
                )
                
                vehicle_owners.append(vehicle_owner)
                if created:
                    self.stdout.write(f'Created VehicleOwner for {user.username}')
                    
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating VehicleOwner for {user.username}: {str(e)}'))
        
        return vehicle_owners
    
    def create_vehicle_types(self):
        self.stdout.write('Creating vehicle types...')
        vehicle_types = []
        
        types_data = [
            {'name': 'Sedan', 'code': 'SEDAN', 'description': 'Standard 4-door car'},
            {'name': 'SUV', 'code': 'SUV', 'description': 'Sport Utility Vehicle'},
            {'name': 'Motorcycle', 'code': 'MOTO', 'description': 'Two-wheeled motor vehicle'},
            {'name': 'Truck', 'code': 'TRUCK', 'description': 'Large goods vehicle'},
            {'name': 'Bus', 'code': 'BUS', 'description': 'Passenger carrying vehicle'}
        ]
        
        for type_data in types_data:
            vtype, created = VehicleType.objects.get_or_create(
                code=type_data['code'],
                defaults={
                    'name': type_data['name'],
                    'description': type_data['description'],
                    'is_active': True
                }
            )
            vehicle_types.append(vtype)
            if created:
                self.stdout.write(f'Created vehicle type: {vtype.name}')
        
        return vehicle_types
    
    def create_vehicles(self, vehicle_owners, vehicle_types):
        self.stdout.write('Creating vehicles...')
        vehicles = []
        
        # Sample vehicle data
        vehicles_data = [
            {
                'license_plate': 'BA 1 PA 1234',
                'nickname': 'My Sedan',
                'make': 'Toyota',
                'model': 'Corolla',
                'year': 2020,
                'color': 'White',
                'registration_number': 'REG12345',
                'is_insured': True,
                'insurance_provider': 'Nepal Insurance',
                'insurance_policy_number': 'POL123456',
                'vehicle_type_code': 'SEDAN'
            },
            {
                'license_plate': 'BA 2 PA 5678',
                'nickname': 'Family SUV',
                'make': 'Honda',
                'model': 'CR-V',
                'year': 2021,
                'color': 'Black',
                'registration_number': 'REG67890',
                'is_insured': True,
                'insurance_provider': 'Himalayan Insurance',
                'insurance_policy_number': 'POL789012',
                'vehicle_type_code': 'SUV'
            },
            {
                'license_plate': 'GA 1 KHA 4321',
                'nickname': 'Work Truck',
                'make': 'Tata',
                'model': 'Pickup',
                'year': 2019,
                'color': 'Blue',
                'registration_number': 'REG54321',
                'is_insured': True,
                'insurance_provider': 'Everest Insurance',
                'insurance_policy_number': 'POL654321',
                'vehicle_type_code': 'TRUCK'
            },
            {
                'license_plate': 'BA 3 PA 9876',
                'nickname': 'City Bike',
                'make': 'Bajaj',
                'model': 'Pulsar',
                'year': 2022,
                'color': 'Red',
                'registration_number': 'REG98765',
                'is_insured': False,
                'insurance_provider': '',
                'insurance_policy_number': '',
                'vehicle_type_code': 'MOTO'
            }
        ]
        
        for i, vehicle_data in enumerate(vehicles_data):
            # Assign to vehicle owners (alternating between the available owners)
            owner = vehicle_owners[i % len(vehicle_owners)]
            
            # Find the corresponding vehicle type
            vehicle_type_code = vehicle_data.pop('vehicle_type_code')
            vehicle_type = next((vt for vt in vehicle_types if vt.code == vehicle_type_code), vehicle_types[0])
            
            # Set registration and insurance expiry dates
            today = timezone.now().date()
            registration_expiry = today + timedelta(days=365 if i % 2 == 0 else -30)  # Some expired, some valid
            insurance_expiry = today + timedelta(days=400 if i % 2 == 0 else -15)  # Some expired, some valid
            
            # Create the vehicle
            try:
                vehicle, created = Vehicle.objects.get_or_create(
                    license_plate=vehicle_data['license_plate'],
                    defaults={
                        'nickname': vehicle_data['nickname'],
                        'make': vehicle_data['make'],
                        'model': vehicle_data['model'],
                        'year': vehicle_data['year'],
                        'color': vehicle_data['color'],
                        'registration_number': vehicle_data['registration_number'],
                        'registration_expiry': registration_expiry,
                        'is_insured': vehicle_data['is_insured'],
                        'insurance_provider': vehicle_data['insurance_provider'],
                        'insurance_policy_number': vehicle_data['insurance_policy_number'],
                        'insurance_expiry': insurance_expiry,
                        'vehicle_type': vehicle_type.code,
                        'owner': owner,
                        'is_active': True
                    }
                )
                vehicles.append(vehicle)
                if created:
                    self.stdout.write(f'Created vehicle: {vehicle.license_plate} for {owner.name}')
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating vehicle {vehicle_data["license_plate"]}: {str(e)}'))
        
        return vehicles
    
    def create_violation_types(self):
        self.stdout.write('Creating violation types...')
        violation_types = []
        
        types_data = [
            {
                'name': 'Speeding',
                'description': 'Exceeding the speed limit',
                'fine_amount': 1500.00
            },
            {
                'name': 'Parking Violation',
                'description': 'Parking in unauthorized areas',
                'fine_amount': 1000.00
            },
            {
                'name': 'Running Red Light',
                'description': 'Failure to stop at a red light',
                'fine_amount': 2000.00
            },
            {
                'name': 'Driving Without License',
                'description': 'Operating a vehicle without a valid driver\'s license',
                'fine_amount': 3000.00
            },
            {
                'name': 'Drink and Drive',
                'description': 'Operating a vehicle under influence of alcohol',
                'fine_amount': 5000.00
            }
        ]
        
        for type_data in types_data:
            try:
                vtype, created = ViolationType.objects.get_or_create(
                    name=type_data['name'],
                    defaults={
                        'description': type_data['description'],
                        'fine_amount': type_data['fine_amount'],
                        'is_active': True
                    }
                )
                violation_types.append(vtype)
                if created:
                    self.stdout.write(f'Created violation type: {vtype.name}')
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating violation type {type_data["name"]}: {str(e)}'))
        
        return violation_types
    
    def create_violations(self, users, vehicles, violation_types):
        self.stdout.write('Creating violations...')
        violations = []
        
        # Get traffic officer users
        officers = [user for user in users if user.user_type == 'officer']
        
        # Create 3 violations for each vehicle
        for vehicle in vehicles:
            for i in range(3):
                try:
                    # Select random violation type and officer
                    violation_type = random.choice(violation_types)
                    officer = random.choice(officers)
                    
                    # Set some violations as pending, some as paid
                    status = random.choice(['pending', 'paid', 'pending'])
                    
                    # Create violation date (some recent, some older)
                    violation_date = timezone.now() - timedelta(days=random.randint(0, 60))
                    
                    # Create locations
                    locations = [
                        "Thamel, Kathmandu",
                        "New Road, Kathmandu",
                        "Durbar Marg, Kathmandu",
                        "Lagankhel, Lalitpur",
                        "Kalanki, Kathmandu"
                    ]
                    location = random.choice(locations)
                    
                    # Create payment date for paid violations
                    payment_date = violation_date + timedelta(days=random.randint(1, 7)) if status == 'paid' else None
                    
                    # Create violation with appropriate fields
                    violation_data = {
                        'vehicle': vehicle,
                        'violation_type': violation_type,
                        'location': location,
                        'description': f"Violation of {violation_type.name} at {location}",
                        'status': status,
                        'fine_amount': violation_type.fine_amount,
                    }
                    
                    # Add fields that might be different based on model definition
                    if hasattr(Violation, 'violation_date'):
                        violation_data['violation_date'] = violation_date
                    elif hasattr(Violation, 'date'):
                        violation_data['date'] = violation_date
                        
                    if hasattr(Violation, 'paid_amount'):
                        violation_data['paid_amount'] = violation_type.fine_amount if status == 'paid' else 0
                        
                    if hasattr(Violation, 'payment_date'):
                        violation_data['payment_date'] = payment_date
                        
                    if hasattr(Violation, 'reported_by'):
                        violation_data['reported_by'] = officer
                    
                    # Create the violation
                    violation = Violation.objects.create(**violation_data)
                    violations.append(violation)
                    self.stdout.write(f'Created violation: {violation.violation_type.name} for {violation.vehicle.license_plate}')
                except Exception as e:
                    self.stdout.write(self.style.ERROR(f'Error creating violation for vehicle {vehicle.license_plate}: {str(e)}'))
        
        return violations
    
    def create_violation_appeals(self, users, violations):
        self.stdout.write('Creating violation appeals...')
        appeals = []
        
        # Create appeals for some pending violations
        pending_violations = [v for v in violations if v.status == 'pending']
        violations_to_appeal = random.sample(pending_violations, k=min(len(pending_violations), 5))
        
        appeal_statuses = ['pending', 'approved', 'rejected']
        
        for violation in violations_to_appeal:
            try:
                status = random.choice(appeal_statuses)
                
                # Get the User object related to this vehicle owner
                vehicle_owner = violation.vehicle.owner
                appealed_by = None
                
                # Find corresponding user for this vehicle owner
                for u in users:
                    if u.user_type == 'vehicle_owner' and u.email == vehicle_owner.email:
                        appealed_by = u
                        break
                
                if appealed_by:
                    appeal = ViolationAppeal.objects.create(
                        violation=violation,
                        appealed_by=appealed_by,
                        reason=f"Appeal for {violation.violation_type.name} violation. This was due to an emergency situation.",
                        status=status,
                    )
                    
                    appeals.append(appeal)
                    self.stdout.write(f'Created appeal for violation {violation.id} with status {status}')
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating appeal for violation {violation.id}: {str(e)}'))
        
        return appeals
    
    def create_notifications(self, users, violations, appeals):
        self.stdout.write('Creating notifications...')
        notifications = []
        
        # Create violation notifications
        for violation in violations:
            try:
                # Get the User object related to this vehicle owner
                vehicle_owner = violation.vehicle.owner
                user = None
                
                # Find corresponding user for this vehicle owner
                for u in users:
                    if u.user_type == 'vehicle_owner' and u.email == vehicle_owner.email:
                        user = u
                        break
                
                if user:
                    notification = Notification.objects.create(
                        user=user,
                        title=f"New Traffic Violation: {violation.violation_type.name}",
                        message=f"Your vehicle with license plate {violation.vehicle.license_plate} was involved in a {violation.violation_type.name} violation at {violation.location}.",
                        notification_type='violation',
                        is_read=random.choice([True, False]),
                        related_violation=violation if hasattr(Notification, 'related_violation') else None
                    )
                    notifications.append(notification)
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating notification for violation {violation.id}: {str(e)}'))
            
        # Create appeal notifications
        for appeal in appeals:
            try:
                # Get the User object related to this vehicle owner
                vehicle_owner = appeal.violation.vehicle.owner
                user = None
                
                # Find corresponding user for this vehicle owner
                for u in users:
                    if u.user_type == 'vehicle_owner' and u.email == vehicle_owner.email:
                        user = u
                        break
                
                if user:
                    notification = Notification.objects.create(
                        user=user,
                        title=f"Appeal Status Update: {appeal.get_status_display()}",
                        message=f"Your appeal for the {appeal.violation.violation_type.name} violation has been {appeal.get_status_display()}.",
                        notification_type='appeal',
                        is_read=random.choice([True, False]),
                        related_violation=appeal.violation if hasattr(Notification, 'related_violation') else None
                    )
                    notifications.append(notification)
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating notification for appeal {appeal.id}: {str(e)}'))
        
        # Create system notifications
        notifications.extend(self.create_system_notifications(users))
        
        return notifications
    
    def create_system_notifications(self, users):
        self.stdout.write('Creating system notifications...')
        notifications = []
        
        # Create system notifications for all users
        system_messages = [
            "Welcome to Smart Traffic Management System!",
            "Your profile has been verified successfully.",
            "New feature alert: QR code scanning is now available for vehicle identification."
        ]
        
        for user in users:
            try:
                message = random.choice(system_messages)
                notification = Notification.objects.create(
                    user=user,
                    title="System Notification",
                    message=message,
                    notification_type='system',
                    is_read=random.choice([True, False])
                )
                notifications.append(notification)
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error creating system notification for user {user.username}: {str(e)}'))
        
        self.stdout.write(f'Created {len(notifications)} system notifications')
        return notifications 