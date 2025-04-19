#!/usr/bin/env python
"""
Script to add sample vehicles and violations for existing users.
"""
import os
import django
from datetime import datetime, timedelta
from django.utils import timezone

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sutms_project.settings')
django.setup()

from accounts.models import User
from vehicles.models import Vehicle, VehicleType
from violations.models import Violation, ViolationType

def create_vehicle_types():
    """Create vehicle types if they don't exist."""
    types = [
        {'name': 'Car', 'code': 'CAR'},
        {'name': 'Motorcycle', 'code': 'MOTOR'},
        {'name': 'SUV', 'code': 'SUV'},
        {'name': 'Truck', 'code': 'TRUCK'},
    ]
    
    for type_data in types:
        VehicleType.objects.get_or_create(
            code=type_data['code'],
            defaults={'name': type_data['name']}
        )

def create_violation_types():
    """Create violation types if they don't exist."""
    types = [
        {
            'name': 'Speeding',
            'description': 'Exceeding the speed limit',
            'fine_amount': 1500.00,
            'is_active': True
        },
        {
            'name': 'Red Light',
            'description': 'Running a red light',
            'fine_amount': 2000.00,
            'is_active': True
        },
        {
            'name': 'No Parking',
            'description': 'Parking in a no-parking zone',
            'fine_amount': 500.00,
            'is_active': True
        },
        {
            'name': 'No Helmet',
            'description': 'Riding without a helmet',
            'fine_amount': 1000.00,
            'is_active': True
        },
    ]
    
    for type_data in types:
        ViolationType.objects.get_or_create(
            name=type_data['name'],
            defaults={
                'description': type_data['description'],
                'fine_amount': type_data['fine_amount'],
                'is_active': type_data['is_active']
            }
        )

def add_sample_data():
    """Add sample vehicles and violations for existing users."""
    # Create vehicle and violation types
    create_vehicle_types()
    create_violation_types()
    
    # Get vehicle types
    car_type = VehicleType.objects.get(code='CAR')
    motor_type = VehicleType.objects.get(code='MOTOR')
    
    # Get violation types
    speeding_type = ViolationType.objects.get(name='Speeding')
    redlight_type = ViolationType.objects.get(name='Red Light')
    nopark_type = ViolationType.objects.get(name='No Parking')
    nohelmet_type = ViolationType.objects.get(name='No Helmet')
    
    # Get all vehicle owners
    vehicle_owners = User.objects.filter(user_type='vehicle_owner')
    
    # Sample vehicle data
    vehicles_data = [
        {
            'license_plate': 'बा२च१२३४',
            'vehicle_type': car_type,
            'make': 'Toyota',
            'model': 'Corolla',
            'color': 'White',
            'year': 2019,
            'is_insured': True,
            'insurance_provider': 'Nepal Insurance',
            'insurance_policy_number': 'NEP-INS-001',
            'insurance_expiry': timezone.now().date() + timedelta(days=180),
            'vin': 'NEP123456789',
            'registration_number': 'REG-2019-001',
            'registration_expiry': timezone.now().date() + timedelta(days=365),
            'nickname': 'Family Car'
        },
        {
            'license_plate': 'बा१५च५६७८',
            'vehicle_type': motor_type,
            'make': 'Honda',
            'model': 'CB Hornet',
            'color': 'Black',
            'year': 2020,
            'is_insured': True,
            'insurance_provider': 'Nepal Insurance',
            'insurance_policy_number': 'NEP-INS-002',
            'insurance_expiry': timezone.now().date() + timedelta(days=90),
            'vin': 'NEP987654321',
            'registration_number': 'REG-2020-002',
            'registration_expiry': timezone.now().date() + timedelta(days=180),
            'nickname': 'Daily Commuter'
        },
        {
            'license_plate': 'प्र२०२१२३४',
            'vehicle_type': car_type,
            'make': 'Hyundai',
            'model': 'Creta',
            'color': 'Silver',
            'year': 2021,
            'is_insured': True,
            'insurance_provider': 'Sagarmatha Insurance',
            'insurance_policy_number': 'SAG-INS-003',
            'insurance_expiry': timezone.now().date() + timedelta(days=270),
            'vin': 'NEP456789123',
            'registration_number': 'REG-2021-003',
            'registration_expiry': timezone.now().date() + timedelta(days=545),
            'nickname': 'Weekend SUV'
        }
    ]
    
    # Add vehicles and violations for each user
    for user in vehicle_owners:
        # Add vehicles
        for vehicle_data in vehicles_data:
            vehicle, created = Vehicle.objects.get_or_create(
                license_plate=vehicle_data['license_plate'],
                defaults={
                    'owner': user,
                    'vehicle_type': vehicle_data['vehicle_type'],
                    'make': vehicle_data['make'],
                    'model': vehicle_data['model'],
                    'color': vehicle_data['color'],
                    'year': vehicle_data['year'],
                    'is_insured': vehicle_data['is_insured'],
                    'insurance_provider': vehicle_data['insurance_provider'],
                    'insurance_policy_number': vehicle_data['insurance_policy_number'],
                    'insurance_expiry': vehicle_data['insurance_expiry'],
                    'vin': vehicle_data['vin'],
                    'registration_number': vehicle_data['registration_number'],
                    'registration_expiry': vehicle_data['registration_expiry'],
                    'nickname': vehicle_data['nickname']
                }
            )
            
            if created:
                # Generate QR code for the vehicle
                vehicle.generate_qr_code()
                
                # Add violations for this vehicle
                violations_data = [
                    {
                        'violation_type': speeding_type,
                        'location': 'Ring Road, Koteshwor',
                        'timestamp': timezone.now() - timedelta(days=30),
                        'description': 'Exceeded speed limit by 20 km/h',
                        'fine_amount': 1500.00,
                        'status': 'pending',
                        'evidence_image': None,
                    },
                    {
                        'violation_type': redlight_type,
                        'location': 'Kalanki Chowk',
                        'timestamp': timezone.now() - timedelta(days=15),
                        'description': 'Ran red light at intersection',
                        'fine_amount': 2000.00,
                        'status': 'approved',
                        'evidence_image': None,
                    },
                    {
                        'violation_type': nopark_type,
                        'location': 'New Road, Kathmandu',
                        'timestamp': timezone.now() - timedelta(days=7),
                        'description': 'Parked in no-parking zone',
                        'fine_amount': 500.00,
                        'status': 'pending',
                        'evidence_image': None,
                    }
                ]
                
                for violation_data in violations_data:
                    Violation.objects.create(
                        vehicle=vehicle,
                        reported_by=User.objects.filter(user_type='officer').first(),
                        **violation_data
                    )

if __name__ == '__main__':
    add_sample_data()
    print("Sample data added successfully!") 