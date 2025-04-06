"""
WSGI application for the SUTMS Django application.
"""
import os
import sys

# Add the sutms_django directory to the Python path
sys.path.insert(0, os.path.abspath('sutms_django'))

# Configure the environment variable for Django settings
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sutms.settings')

try:
    from django.core.wsgi import get_wsgi_application
    app = get_wsgi_application()
except Exception as e:
    def app(environ, start_response):
        """Fallback WSGI app function for error cases"""
        status = '500 Internal Server Error'
        response_headers = [('Content-type', 'text/plain')]
        start_response(status, response_headers)
        return [f"Error loading Django application: {str(e)}".encode('utf-8')]