"""
Simplified Stripe wrapper for development.
This is a temporary file to allow the application to start up without Stripe.
"""

def create_checkout_session(payment, success_url=None, cancel_url=None):
    """Dummy function that returns a success response"""
    return {
        'success': True,
        'session_id': 'mock_session_id',
        'checkout_url': 'https://example.com/checkout',
        'payment': payment,
    }

def handle_webhook_event(event_data):
    """Dummy function that returns True"""
    return True

def get_payment_status(payment):
    """Dummy function that returns a success response"""
    return {
        'success': True,
        'stripe_status': 'unpaid',
        'status': payment.status,
    }

def create_payment_receipt(payment):
    """Dummy function that does nothing"""
    pass

def refund_payment(payment, amount=None, reason=None):
    """Dummy function that returns a success response"""
    return {
        'success': True,
        'refund_id': 'mock_refund_id',
        'amount': amount or payment.amount,
    } 