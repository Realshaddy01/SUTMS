#!/usr/bin/env python
"""
Entry point for running the SUTMS Django application
"""
import os
import sys
import logging
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

# Set the Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sutms.settings')

# Configure Django
import django
django.setup()

# Create necessary directories
from django.conf import settings
os.makedirs(settings.MEDIA_ROOT, exist_ok=True)
os.makedirs(settings.STATIC_ROOT, exist_ok=True)
os.makedirs(os.path.join(settings.MEDIA_ROOT, 'temp'), exist_ok=True)

# Run development server when invoked directly
if __name__ == '__main__':
    from django.core.management import execute_from_command_line
    execute_from_command_line(['manage.py', 'runserver', '0.0.0.0:8000'])