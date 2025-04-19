import os
import django

# Set up Django environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sutms_project.settings')
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()

def create_admin():
    """Create a superuser admin account"""
    if User.objects.filter(username='admin').exists():
        print("Admin user already exists")
        return False
    
    try:
        admin = User.objects.create_superuser(
            username='admin',
            email='admin@example.com',
            password='admin123',
            user_type='admin'
        )
        print(f"Admin superuser created successfully: {admin.username}")
        print("Username: admin")
        print("Password: admin123")
        return True
    except Exception as e:
        print(f"Error creating admin user: {str(e)}")
        return False

if __name__ == "__main__":
    create_admin() 