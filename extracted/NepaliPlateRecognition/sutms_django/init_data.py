#!/usr/bin/env python
"""
Database initialization script for SUTMS.
Creates initial data such as admin users, common violation types, etc.
"""
import os
import django
import logging
from datetime import datetime, timedelta

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sutms.settings')
django.setup()

# Now we can import Django models
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone

# Import models from our apps
from accounts.models import User, UserProfile
from vehicles.models import Vehicle
from violations.models import ViolationType, Violation
from tracking.models import TrafficSignal, TrafficIncident

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
)
logger = logging.getLogger(__name__)

def create_users():
    """Create initial users with different roles."""
    logger.info("Creating initial users...")
    
    # Create admin user
    admin_user, created = User.objects.get_or_create(
        username='admin',
        defaults={
            'email': 'admin@sutms.com',
            'user_type': User.UserType.ADMIN,
            'first_name': 'System',
            'last_name': 'Admin',
            'phone_number': '+977 98XXXXXXXX',
            'is_staff': True,
            'is_superuser': True,
        }
    )
    if created:
        admin_user.set_password('admin@123')
        admin_user.save()
        UserProfile.objects.get_or_create(user=admin_user)
        logger.info("Created admin user: admin / admin@123")
    
    # Create officer user
    officer_user, created = User.objects.get_or_create(
        username='officer',
        defaults={
            'email': 'officer@sutms.com',
            'user_type': User.UserType.OFFICER,
            'first_name': 'Traffic',
            'last_name': 'Officer',
            'phone_number': '+977 98XXXXXXXX',
            'badge_number': 'NEP-OFF-001',
        }
    )
    if created:
        officer_user.set_password('officer@123')
        officer_user.save()
        UserProfile.objects.get_or_create(
            user=officer_user,
            defaults={
                'bio': 'Senior Traffic Officer in Kathmandu',
                'is_verified': True,
            }
        )
        logger.info("Created officer user: officer / officer@123")
    
    # Create vehicle owner user
    owner_user, created = User.objects.get_or_create(
        username='owner',
        defaults={
            'email': 'owner@sutms.com',
            'user_type': User.UserType.VEHICLE_OWNER,
            'first_name': 'Vehicle',
            'last_name': 'Owner',
            'phone_number': '+977 98XXXXXXXX',
        }
    )
    if created:
        owner_user.set_password('owner@123')
        owner_user.save()
        UserProfile.objects.get_or_create(
            user=owner_user,
            defaults={
                'bio': 'Vehicle owner in Kathmandu',
                'is_verified': True,
            }
        )
        logger.info("Created vehicle owner user: owner / owner@123")
    
    return admin_user, officer_user, owner_user

def create_vehicles(owner_user):
    """Create sample vehicles for the owner user."""
    logger.info("Creating sample vehicles...")
    
    vehicles = [
        {
            'license_plate': 'BA 1 PA 1234',
            'vehicle_type': 'Car',
            'make': 'Toyota',
            'model': 'Corolla',
            'color': 'White',
            'year': 2019,
            'registration_date': timezone.now().date() - timedelta(days=365),
        },
        {
            'license_plate': 'BA 2 CHA 5678',
            'vehicle_type': 'Motorcycle',
            'make': 'Honda',
            'model': 'CB Hornet',
            'color': 'Black',
            'year': 2020,
            'registration_date': timezone.now().date() - timedelta(days=180),
        },
        {
            'license_plate': 'BA 3 JHA 9012',
            'vehicle_type': 'SUV',
            'make': 'Hyundai',
            'model': 'Creta',
            'color': 'Red',
            'year': 2021,
            'registration_date': timezone.now().date() - timedelta(days=90),
        },
    ]
    
    created_vehicles = []
    for data in vehicles:
        vehicle, created = Vehicle.objects.get_or_create(
            license_plate=data['license_plate'],
            defaults={
                'owner': owner_user,
                'vehicle_type': data['vehicle_type'],
                'make': data['make'],
                'model': data['model'],
                'color': data['color'],
                'year': data['year'],
                'registration_date': data['registration_date'],
            }
        )
        if created:
            logger.info(f"Created vehicle: {vehicle.license_plate}")
            # Generate QR code for the vehicle
            vehicle.generate_qr_code()
            created_vehicles.append(vehicle)
    
    return created_vehicles

def create_violation_types():
    """Create common violation types."""
    logger.info("Creating violation types...")
    
    violation_types = [
        {
            'name': 'Speeding',
            'description': 'Exceeding the speed limit',
            'fine_amount': 1500.00,
            'penalty_points': 3,
        },
        {
            'name': 'Red Light',
            'description': 'Running a red light',
            'fine_amount': 1000.00,
            'penalty_points': 4,
        },
        {
            'name': 'No Parking',
            'description': 'Parking in a no-parking zone',
            'fine_amount': 500.00,
            'penalty_points': 1,
        },
        {
            'name': 'Wrong Way',
            'description': 'Driving against the direction of traffic',
            'fine_amount': 2000.00,
            'penalty_points': 5,
        },
        {
            'name': 'No Helmet',
            'description': 'Riding without a helmet',
            'fine_amount': 500.00,
            'penalty_points': 2,
        },
        {
            'name': 'Drunk Driving',
            'description': 'Driving under the influence of alcohol',
            'fine_amount': 5000.00,
            'penalty_points': 10,
        },
    ]
    
    created_types = []
    for data in violation_types:
        vtype, created = ViolationType.objects.get_or_create(
            name=data['name'],
            defaults={
                'description': data['description'],
                'fine_amount': data['fine_amount'],
                'penalty_points': data['penalty_points'],
            }
        )
        if created:
            logger.info(f"Created violation type: {vtype.name}")
            created_types.append(vtype)
    
    return created_types

def create_traffic_signals():
    """Create sample traffic signals."""
    logger.info("Creating sample traffic signals...")
    
    signals = [
        {
            'name': 'Kalanki Junction',
            'street_name': 'Ring Road - Kalanki',
            'latitude': 27.6939,
            'longitude': 85.2806,
            'status': 'operational',
            'current_phase': 'red',
            'time_remaining': 30,
        },
        {
            'name': 'Koteshwor Junction',
            'street_name': 'Ring Road - Koteshwor',
            'latitude': 27.6775,
            'longitude': 85.3489,
            'status': 'operational',
            'current_phase': 'green',
            'time_remaining': 45,
        },
        {
            'name': 'New Baneshwor',
            'street_name': 'Mid-Baneshwor Road',
            'latitude': 27.6883,
            'longitude': 85.3395,
            'status': 'operational',
            'current_phase': 'yellow',
            'time_remaining': 10,
        },
        {
            'name': 'Thapathali Junction',
            'street_name': 'Tripureshwor - Thapathali',
            'latitude': 27.6934,
            'longitude': 85.3111,
            'status': 'maintenance',
            'current_phase': 'flashing',
            'time_remaining': None,
        },
    ]
    
    created_signals = []
    for data in signals:
        signal, created = TrafficSignal.objects.get_or_create(
            name=data['name'],
            defaults={
                'street_name': data['street_name'],
                'latitude': data['latitude'],
                'longitude': data['longitude'],
                'status': data['status'],
                'current_phase': data['current_phase'],
                'time_remaining': data['time_remaining'],
            }
        )
        if created:
            logger.info(f"Created traffic signal: {signal.name}")
            created_signals.append(signal)
    
    return created_signals

def create_sample_violations(vehicles, officer_user, violation_types):
    """Create sample violations for testing."""
    logger.info("Creating sample violations...")
    
    # We'll create one violation of each type for the first vehicle
    if not vehicles or not violation_types:
        logger.warning("No vehicles or violation types to create violations")
        return []
    
    created_violations = []
    vehicle = vehicles[0]
    
    for i, vtype in enumerate(violation_types):
        # Create violations at different dates and statuses for variety
        days_ago = i * 5
        status = ['pending', 'paid', 'disputed'][i % 3]
        
        violation = Violation.objects.create(
            vehicle=vehicle,
            violation_type=vtype,
            officer=officer_user,
            location=f"Test Location {i+1}",
            latitude=27.7 + (i * 0.01),
            longitude=85.3 + (i * 0.01),
            fine_amount=vtype.fine_amount,
            penalty_points=vtype.penalty_points,
            status=status,
            violation_date=timezone.now() - timedelta(days=days_ago),
            description=f"Sample violation of type {vtype.name}",
        )
        logger.info(f"Created violation: {violation}")
        created_violations.append(violation)
        
        # Create a notification for the vehicle owner about this violation
        from django.contrib.contenttypes.models import ContentType
        from notifications.models import Notification
        
        if vehicle.owner:
            Notification.objects.create(
                recipient=vehicle.owner,
                actor=officer_user,
                verb=f"reported a {vtype.name} violation",
                action_object_content_type=ContentType.objects.get_for_model(Violation),
                action_object_object_id=violation.id,
                description=f"Your vehicle with license plate {vehicle.license_plate} was involved in a {vtype.name} violation.",
            )
            
    return created_violations

@transaction.atomic
def init_data():
    """Initialize the database with sample data."""
    try:
        logger.info("Initializing database with sample data...")
        
        # Create users
        admin_user, officer_user, owner_user = create_users()
        
        # Create vehicles for the owner
        vehicles = create_vehicles(owner_user)
        
        # Create violation types
        violation_types = create_violation_types()
        
        # Create traffic signals
        traffic_signals = create_traffic_signals()
        
        # Create sample violations
        violations = create_sample_violations(vehicles, officer_user, violation_types)
        
        logger.info("Database initialization complete!")
        
        # Return summary
        return {
            'users': [admin_user, officer_user, owner_user],
            'vehicles': vehicles,
            'violation_types': violation_types,
            'traffic_signals': traffic_signals,
            'violations': violations,
        }
    
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
        raise

if __name__ == "__main__":
    init_data()