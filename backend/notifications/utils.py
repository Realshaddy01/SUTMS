import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
import os
import json

# Initialize Firebase Admin SDK
def initialize_firebase():
    if not firebase_admin._apps:
        # Check if credentials file exists
        if os.path.exists(settings.FIREBASE_CREDENTIALS):
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
            firebase_admin.initialize_app(cred)
        else:
            # Create a dummy credentials file for development
            dummy_creds = {
                "type": "service_account",
                "project_id": "sutms-dummy",
                "private_key_id": "dummy",
                "private_key": "-----BEGIN PRIVATE KEY-----\nDUMMY\n-----END PRIVATE KEY-----\n",
                "client_email": "dummy@sutms-dummy.iam.gserviceaccount.com",
                "client_id": "123456789",
                "auth_uri": "https://accounts.google.com/o/oauth2/auth",
                "token_uri": "https://oauth2.googleapis.com/token",
                "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
                "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/dummy"
            }
            
            # Save dummy credentials to file
            with open(settings.FIREBASE_CREDENTIALS, 'w') as f:
                json.dump(dummy_creds, f)
            
            cred = credentials.Certificate(settings.FIREBASE_CREDENTIALS)
            firebase_admin.initialize_app(cred)

def send_notification(token, title, body, data=None):
    try:
        # Initialize Firebase if not already initialized
        initialize_firebase()
        
        # Create message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            token=token,
        )
        
        # Send message
        response = messaging.send(message)
        return response
    except Exception as e:
        print(f"Error sending notification: {e}")
        return None

def send_topic_notification(topic, title, body, data=None):
    try:
        # Initialize Firebase if not already initialized
        initialize_firebase()
        
        # Create message
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data or {},
            topic=topic,
        )
        
        # Send message
        response = messaging.send(message)
        return response
    except Exception as e:
        print(f"Error sending topic notification: {e}")
        return None

