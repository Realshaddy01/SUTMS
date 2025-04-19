from django.core.management.base import BaseCommand
from django.contrib.auth.models import User, Group
from vehicles.models import Vehicle, VehicleOwner, Violation, ViolationType
from django.utils import timezone
import random
from datetime import datetime, timedelta

class Command(BaseCommand):
    help = 'Seeds the database with mock data for testing and demonstration'

    def handle(self, *args, **kwargs):
        self.stdout.write('Starting to seed mock data...')
        
        # Create test users
        self.create_test_users()
        
        # Create violation types
        self.create_violation_types()
        
        # Create vehicle owners
        owners = self.create_vehicle_owners()
        
        # Create vehicles
        vehicles = self.create_vehicles(owners)
        
        # Create violations
        self.create_violations(vehicles)
        
        self.stdout.write(self.style.SUCCESS('Successfully seeded mock data!'))

    def create_test_users(self):
        # Create admin user
        admin, created = User.objects.get_or_create(
            username='admin',
            defaults={
                'email': 'admin@traffic.gov.np',
                'is_staff': True,
                'is_superuser': True
            }
        )
        if created:
            admin.set_password('admin123')
            admin.save()
            self.stdout.write('Created admin user')

        # Create traffic officer user
        officer, created = User.objects.get_or_create(
            username='officer',
            defaults={
                'email': 'officer@traffic.gov.np',
                'is_staff': True
            }
        )
        if created:
            officer.set_password('officer123')
            officer.save()
            self.stdout.write('Created traffic officer user')

    def create_violation_types(self):
        violation_types = [
            ('SPEEDING', 'Exceeding speed limit', 5000),
            ('RED_LIGHT', 'Running red light', 3000),
            ('NO_HELMET', 'Not wearing helmet', 1000),
            ('NO_SEATBELT', 'Not wearing seatbelt', 1000),
            ('PARKING', 'Illegal parking', 2000),
            ('DOCUMENTS', 'Missing documents', 1500),
            ('MOBILE', 'Using mobile while driving', 2000),
            ('DRUNK', 'Driving under influence', 10000),
        ]
        
        for code, description, fine_amount in violation_types:
            ViolationType.objects.get_or_create(
                code=code,
                defaults={
                    'description': description,
                    'fine_amount': fine_amount
                }
            )
        self.stdout.write('Created violation types')

    def create_vehicle_owners(self):
        owners = []
        owner_data = [
            ('Ram Bahadur', 'ram.bahadur@email.com', '9841000001'),
            ('Shyam Kumar', 'shyam.kumar@email.com', '9841000002'),
            ('Hari Prasad', 'hari.prasad@email.com', '9841000003'),
            ('Sita Devi', 'sita.devi@email.com', '9841000004'),
            ('Gita Kumari', 'gita.kumari@email.com', '9841000005'),
        ]
        
        for name, email, phone in owner_data:
            owner, created = VehicleOwner.objects.get_or_create(
                name=name,
                defaults={
                    'email': email,
                    'phone': phone,
                    'address': f'Kathmandu, Nepal - {random.randint(1, 100)}',
                    'license_number': f'DL-{random.randint(10000, 99999)}'
                }
            )
            if created:
                owners.append(owner)
        
        self.stdout.write('Created vehicle owners')
        return owners

    def create_vehicles(self, owners):
        vehicles = []
        vehicle_data = [
            ('Ba 1 Pa 1234', 'CAR', 'Toyota', 'Corolla', 2020, 'Blue'),
            ('Ba 2 Pa 5678', 'MOTORCYCLE', 'Honda', 'CBR', 2021, 'Red'),
            ('Ba 3 Pa 9012', 'CAR', 'Suzuki', 'Swift', 2019, 'White'),
            ('Ba 4 Pa 3456', 'MOTORCYCLE', 'Yamaha', 'FZ', 2022, 'Black'),
            ('Ba 5 Pa 7890', 'CAR', 'Hyundai', 'i20', 2021, 'Silver'),
        ]
        
        for plate, v_type, make, model, year, color in vehicle_data:
            owner = random.choice(owners)
            vehicle, created = Vehicle.objects.get_or_create(
                license_plate=plate,
                defaults={
                    'owner': owner,
                    'vehicle_type': v_type,
                    'make': make,
                    'model': model,
                    'year': year,
                    'color': color,
                    'registration_number': f'REG-{random.randint(10000, 99999)}',
                    'registration_expiry': timezone.now() + timedelta(days=random.randint(30, 365)),
                    'insurance_expiry': timezone.now() + timedelta(days=random.randint(30, 365)),
                    'is_active': True
                }
            )
            if created:
                vehicles.append(vehicle)
        
        self.stdout.write('Created vehicles')
        return vehicles

    def create_violations(self, vehicles):
        violation_types = list(ViolationType.objects.all())
        status_choices = ['pending', 'paid', 'cancelled']
        
        for vehicle in vehicles:
            # Create 2-5 violations per vehicle
            num_violations = random.randint(2, 5)
            for _ in range(num_violations):
                violation_type = random.choice(violation_types)
                status = random.choice(status_choices)
                violation_date = timezone.now() - timedelta(days=random.randint(1, 90))
                
                Violation.objects.create(
                    vehicle=vehicle,
                    violation_type=violation_type,
                    status=status,
                    violation_date=violation_date,
                    location='Kathmandu, Nepal',
                    description=f'Violation detected at {violation_date.strftime("%Y-%m-%d %H:%M")}',
                    fine_amount=violation_type.fine_amount,
                    paid_amount=violation_type.fine_amount if status == 'paid' else 0,
                    payment_date=violation_date + timedelta(days=random.randint(1, 30)) if status == 'paid' else None
                )
        
        self.stdout.write('Created violations') 