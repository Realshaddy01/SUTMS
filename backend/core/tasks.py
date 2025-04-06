from celery import shared_task
from django.contrib.auth.models import User
from django.utils import timezone
from datetime import timedelta
import logging

logger = logging.getLogger(__name__)

@shared_task
def process_violation_image(violation_id):
    try:
        from .models import Violation
        from ai.license_plate_recognition import recognize_license_plate
        
        # Get the violation
        violation = Violation.objects.get(id=violation_id)
        
        if not violation.evidence_image:
            logger.warning(f"No evidence image for violation {violation_id}")
            return
        
        # Process the image for license plate recognition
        result = recognize_license_plate(violation.evidence_image.path)
        
        if result and 'plate_text' in result and 'confidence' in result:
            violation.detected_license_plate = result['plate_text']
            violation.confidence_score = result['confidence']
            violation.save()
            
            logger.info(f"License plate {result['plate_text']} detected with confidence {result['confidence']}")
            
            # If the confidence is high and the plate matches the vehicle's plate, auto-confirm
            if (result['confidence'] > 0.8 and 
                result['plate_text'].strip().upper() == violation.vehicle.license_plate.strip().upper()):
                violation.status = 'confirmed'
                violation.save()
                logger.info(f"Violation {violation_id} auto-confirmed")
        else:
            logger.warning(f"License plate detection failed for violation {violation_id}")
    
    except Exception as e:
        logger.error(f"Error processing violation image {violation_id}: {str(e)}")

@shared_task
def send_notification(user_id, title, message, violation_id=None):
    try:
        from .models import Notification, Violation
        
        user = User.objects.get(id=user_id)
        
        notification_data = {
            'user': user,
            'title': title,
            'message': message
        }
        
        if violation_id:
            try:
                violation = Violation.objects.get(id=violation_id)
                notification_data['violation'] = violation
            except Violation.DoesNotExist:
                pass
        
        Notification.objects.create(**notification_data)
        
        # Here you would integrate with a push notification service like Firebase
        # For now, we'll just log it
        logger.info(f"Notification sent to {user.username}: {title}")
        
        return True
    except Exception as e:
        logger.error(f"Error sending notification: {str(e)}")
        return False

@shared_task
def clean_old_notifications():
    try:
        from .models import Notification
        
        # Delete read notifications older than 30 days
        thirty_days_ago = timezone.now() - timedelta(days=30)
        old_notifications = Notification.objects.filter(
            is_read=True,
            timestamp__lt=thirty_days_ago
        )
        
        count = old_notifications.count()
        old_notifications.delete()
        
        logger.info(f"Deleted {count} old notifications")
        return count
    except Exception as e:
        logger.error(f"Error cleaning old notifications: {str(e)}")
        return 0
