#!/usr/bin/env python
"""
Script to add a new admin user with proper permissions.
"""
import os
import django
from django.contrib.auth import get_user_model

# Configure Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sutms_project.settings')
django.setup()

from accounts.models import User, UserProfile

def create_admin_user():
    """Create a new admin user with proper permissions."""
    # Admin user details
    admin_data = {
        'username': 'admin2',
        'email': 'admin2@sutms.com',
        'first_name': 'System',
        'last_name': 'Admin 2',
        'user_type': User.UserType.ADMIN,
        'phone_number': '+977 98XXXXXXXX',
        'is_staff': True,
        'is_superuser': True,
    }
    
    # Check if user already exists
    if User.objects.filter(username=admin_data['username']).exists():
        print(f"User {admin_data['username']} already exists!")
        return
    
    # Create admin user
    admin_user = User.objects.create_user(
        username=admin_data['username'],
        email=admin_data['email'],
        password='admin2@123',  # Default password
        **{k: v for k, v in admin_data.items() if k not in ['username', 'email']}
    )
    
    # Create user profile
    UserProfile.objects.create(
        user=admin_user,
        bio='System Administrator',
        is_verified=True
    )
    
    print(f"Admin user created successfully!")
    print(f"Username: {admin_data['username']}")
    print(f"Email: {admin_data['email']}")
    print(f"Password: admin2@123")
    print("\nPlease change the password after first login!")

if __name__ == '__main__':
    create_admin_user() 