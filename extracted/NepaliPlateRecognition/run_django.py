#!/usr/bin/env python
"""
Run script for the SUTMS Django application.
"""
import os
import sys
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler('django_server.log')
    ]
)
logger = logging.getLogger(__name__)

def run_server():
    """Run the Django development server."""
    try:
        logger.info("Starting Django server...")
        os.chdir('sutms_django')
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sutms.settings')
        
        # Make sure required directories exist
        os.makedirs('static', exist_ok=True)
        os.makedirs('media', exist_ok=True)
        
        # Run migrations
        logger.info("Running database migrations...")
        os.system(f"{sys.executable} manage.py migrate")
        
        # Collect static files
        logger.info("Collecting static files...")
        os.system(f"{sys.executable} manage.py collectstatic --noinput")
        
        # Start the server
        logger.info("Starting server on port 5000...")
        os.system(f"{sys.executable} manage.py runserver 0.0.0.0:5000")
    except Exception as e:
        logger.error(f"Error starting Django server: {e}")
        sys.exit(1)

if __name__ == "__main__":
    run_server()