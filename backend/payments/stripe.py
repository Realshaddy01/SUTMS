"""
Stripe payment integration module.
"""
import os
import logging
import stripe
from django.conf import settings
from django.urls import reverse

logger = logging.getLogger('sutms.payments')

# Configure Stripe with the secret key from settings
stripe.api_key = settings.STRIPE_SECRET_KEY

def create_checkout_session(payment, success_url=None, cancel_url=None):
    """
    Create a Stripe checkout session for the given payment.
    
    Args:
        payment (Payment): Payment object to create a session for
        success_url (str, optional): URL to redirect to after successful payment
        cancel_url (str, optional): URL to redirect to if payment is cancelled
    
    Returns:
        dict: Session details including URL to redirect the user to
    """
    # Import here to avoid circular imports
    from .models import Payment
    
    violation = payment.violation
    vehicle = violation.vehicle
    
    # Set default URLs if not provided
    if not success_url:
        success_url = f"{settings.BASE_URL}{reverse('payments:payment_success')}?session_id={{CHECKOUT_SESSION_ID}}"
    if not cancel_url:
        cancel_url = f"{settings.BASE_URL}{reverse('payments:payment_cancel')}?session_id={{CHECKOUT_SESSION_ID}}"
    
    try:
        # Create a Stripe checkout session
        session = stripe.checkout.Session.create(
            payment_method_types=['card'],
            line_items=[{
                'price_data': {
                    'currency': 'npr',  # Nepali Rupee
                    'product_data': {
                        'name': f'Traffic Violation: {violation.violation_type.name}',
                        'description': f'License Plate: {vehicle.license_plate}, Violation Date: {violation.timestamp.strftime("%Y-%m-%d")}',
                        'metadata': {
                            'violation_id': str(violation.id),
                            'vehicle_id': str(vehicle.id),
                        },
                    },
                    'unit_amount': int(payment.amount * 100),  # Convert to paisa (cents equivalent)
                },
                'quantity': 1,
            }],
            mode='payment',
            success_url=success_url,
            cancel_url=cancel_url,
            client_reference_id=str(payment.id),
            customer_email=payment.paid_by.email if payment.paid_by else None,
            metadata={
                'payment_id': str(payment.id),
                'violation_id': str(violation.id),
                'vehicle_id': str(vehicle.id),
                'license_plate': vehicle.license_plate,
                'violation_type': violation.violation_type.name,
                'violation_date': violation.timestamp.strftime('%Y-%m-%d'),
            },
        )
        
        # Update the payment with Stripe session information
        payment.payment_method = Payment.PaymentMethod.STRIPE
        payment.status = Payment.PaymentStatus.PENDING
        payment.stripe_session_id = session.id
        payment.save()
        
        return {
            'success': True,
            'session_id': session.id,
            'checkout_url': session.url,
            'payment': payment,
        }
        
    except stripe.error.StripeError as e:
        # Log the error and return failure response
        logger.error(f"Stripe error: {str(e)}")
        return {
            'success': False,
            'error': str(e),
            'payment': payment,
        }

def handle_webhook_event(event_data):
    """
    Handle a webhook event from Stripe.
    
    Args:
        event_data (dict): Event data from Stripe
    
    Returns:
        bool: True if event was handled successfully
    """
    # Import here to avoid circular imports
    from .models import Payment, PaymentLog
    
    # Verify the event
    try:
        # If webhook signing is configured, verify the signature
        if settings.STRIPE_WEBHOOK_SECRET:
            webhook_secret = settings.STRIPE_WEBHOOK_SECRET
            signature = event_data.get('stripe_signature', '')
            event = stripe.Webhook.construct_event(
                event_data.get('payload', '{}'),
                signature,
                webhook_secret
            )
            event_dict = event
        else:
            # Otherwise, just parse the JSON data
            event_dict = event_data
            
        event_type = event_dict.get('type')
        event_object = event_dict.get('data', {}).get('object', {})
        
        logger.info(f"Processing Stripe webhook event: {event_type}")
        
        # Handle specific event types
        if event_type == 'checkout.session.completed':
            # Payment completed successfully
            session_id = event_object.get('id')
            payment_id = event_object.get('client_reference_id')
            
            # Get the payment
            try:
                payment = Payment.objects.get(id=payment_id, stripe_session_id=session_id)
            except Payment.DoesNotExist:
                logger.error(f"Payment not found for session_id={session_id}, payment_id={payment_id}")
                return False
            
            # Update payment status
            payment.status = Payment.PaymentStatus.COMPLETED
            payment.transaction_id = event_object.get('payment_intent')
            payment.payment_date = timezone.now()
            payment.save()
            
            # Create payment log
            PaymentLog.objects.create(
                payment=payment,
                type=PaymentLog.LogType.SUCCESS,
                message="Payment completed via Stripe",
                data=event_dict
            )
            
            # Generate receipt
            create_payment_receipt(payment)
            
            return True
            
        elif event_type == 'checkout.session.expired':
            # Payment session expired
            session_id = event_object.get('id')
            payment_id = event_object.get('client_reference_id')
            
            # Get the payment
            try:
                payment = Payment.objects.get(id=payment_id, stripe_session_id=session_id)
            except Payment.DoesNotExist:
                logger.error(f"Payment not found for session_id={session_id}, payment_id={payment_id}")
                return False
            
            # Update payment status
            payment.status = Payment.PaymentStatus.CANCELLED
            payment.save()
            
            # Create payment log
            PaymentLog.objects.create(
                payment=payment,
                type=PaymentLog.LogType.FAILURE,
                message="Payment session expired",
                data=event_dict
            )
            
            return True
            
        elif event_type in ['payment_intent.succeeded', 'payment_intent.payment_failed']:
            # These events are handled by checkout.session.completed
            return True
            
        else:
            # Unhandled event type
            logger.info(f"Unhandled Stripe event type: {event_type}")
            return True
            
    except stripe.error.StripeError as e:
        logger.error(f"Stripe webhook error: {str(e)}")
        return False
    except Exception as e:
        logger.error(f"Error processing Stripe webhook: {str(e)}")
        return False

def get_payment_status(payment):
    """
    Get the current status of a payment from Stripe.
    
    Args:
        payment (Payment): Payment object to check status for
    
    Returns:
        dict: Status information
    """
    # Import here to avoid circular imports
    from .models import Payment, PaymentLog
    
    if not payment.stripe_session_id:
        return {
            'success': False,
            'error': 'No Stripe session ID found for this payment',
            'status': payment.status,
        }
        
    try:
        # Retrieve the session from Stripe
        session = stripe.checkout.Session.retrieve(payment.stripe_session_id)
        
        # Check if payment is completed
        if session.payment_status == 'paid' and payment.status != Payment.PaymentStatus.COMPLETED:
            # Update payment status
            payment.status = Payment.PaymentStatus.COMPLETED
            payment.transaction_id = session.payment_intent
            payment.payment_date = timezone.now()
            payment.save()
            
            # Create payment log
            PaymentLog.objects.create(
                payment=payment,
                type=PaymentLog.LogType.SUCCESS,
                message="Payment completed via Stripe (verified by status check)",
                data=session
            )
            
            # Generate receipt
            create_payment_receipt(payment)
            
        # Return status information
        return {
            'success': True,
            'stripe_status': session.payment_status,
            'status': payment.status,
            'session': session,
        }
        
    except stripe.error.StripeError as e:
        # Log the error and return failure response
        logger.error(f"Stripe error checking payment status: {str(e)}")
        return {
            'success': False,
            'error': str(e),
            'status': payment.status,
        }

def create_payment_receipt(payment):
    """
    Generate a payment receipt for a completed payment.
    
    Args:
        payment (Payment): Payment object to generate receipt for
    
    Returns:
        PaymentReceipt: The generated receipt object
    """
    # Import here to avoid circular imports
    from .models import PaymentReceipt
    import uuid
    import json
    
    # Generate receipt number if not already set
    receipt_number = payment.receipt_number or f"RECEIPT-{uuid.uuid4().hex[:8].upper()}"
    
    # Set receipt number on payment if not already set
    if not payment.receipt_number:
        payment.receipt_number = receipt_number
        payment.save(update_fields=['receipt_number'])
    
    # Prepare receipt data
    receipt_data = {
        'receipt_number': receipt_number,
        'payment_id': str(payment.id),
        'payment_date': payment.payment_date.strftime('%Y-%m-%d %H:%M:%S') if payment.payment_date else '',
        'payment_method': payment.get_payment_method_display(),
        'amount': float(payment.amount),
        'currency': 'NPR',  # Nepali Rupee
        'transaction_id': payment.transaction_id,
        'violation_id': str(payment.violation.id),
        'violation_type': payment.violation.violation_type.name,
        'violation_date': payment.violation.timestamp.strftime('%Y-%m-%d'),
        'vehicle': {
            'license_plate': payment.violation.vehicle.license_plate,
            'make': payment.violation.vehicle.make,
            'model': payment.violation.vehicle.model,
            'color': payment.violation.vehicle.color,
            'owner': payment.violation.vehicle.owner.get_full_name() if payment.violation.vehicle.owner else '',
        },
        'paid_by': payment.paid_by.get_full_name() if payment.paid_by else '',
    }
    
    # Create receipt
    try:
        receipt, created = PaymentReceipt.objects.get_or_create(
            payment=payment,
            defaults={
                'receipt_number': receipt_number,
                'receipt_data': json.dumps(receipt_data),
            }
        )
        
        if not created:
            # Update receipt data if it already exists
            receipt.receipt_data = json.dumps(receipt_data)
            receipt.save()
        
        # Generate PDF (this could call a separate function or service)
        # For now, we'll just return the receipt object
        return receipt
        
    except Exception as e:
        logger.error(f"Error generating payment receipt: {str(e)}")
        return None

def refund_payment(payment, amount=None, reason=None):
    """
    Refund a payment via Stripe.
    
    Args:
        payment (Payment): Payment object to refund
        amount (Decimal, optional): Amount to refund. If not provided, refund the full amount.
        reason (str, optional): Reason for the refund.
    
    Returns:
        dict: Refund information
    """
    # Import here to avoid circular imports
    from .models import Payment, PaymentLog
    
    if payment.payment_method != Payment.PaymentMethod.STRIPE:
        return {
            'success': False,
            'error': 'Only Stripe payments can be refunded automatically',
        }
        
    if not payment.stripe_payment_intent_id:
        return {
            'success': False,
            'error': 'No Stripe payment intent ID found for this payment',
        }
        
    try:
        # Get the Stripe payment intent
        payment_intent = stripe.PaymentIntent.retrieve(payment.stripe_payment_intent_id)
        
        # Calculate refund amount
        refund_amount = int((amount or payment.amount) * 100)  # Convert to paisa (cents equivalent)
        
        # Create the refund
        refund = stripe.Refund.create(
            payment_intent=payment.stripe_payment_intent_id,
            amount=refund_amount,
            reason='requested' if reason else None,
            metadata={
                'payment_id': str(payment.id),
                'reason': reason or 'Requested by officer',
            }
        )
        
        # Update payment status
        payment.status = Payment.PaymentStatus.REFUNDED
        payment.save()
        
        # Create payment log
        PaymentLog.objects.create(
            payment=payment,
            type=PaymentLog.LogType.REFUND,
            message=f"Payment refunded: {reason or 'No reason provided'}",
            data=refund
        )
        
        return {
            'success': True,
            'refund_id': refund.id,
            'amount': refund.amount / 100,  # Convert back to rupees
            'status': refund.status,
        }
        
    except stripe.error.StripeError as e:
        # Log the error and return failure response
        logger.error(f"Stripe error during refund: {str(e)}")
        return {
            'success': False,
            'error': str(e),
        }