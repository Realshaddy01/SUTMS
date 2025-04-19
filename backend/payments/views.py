"""
Views for the payments app.
"""
import json
import logging
import uuid
try:
    import stripe
except ImportError:
    # If stripe is not available, use our mock implementation
    stripe = None

from django.conf import settings
from django.shortcuts import render, get_object_or_404, redirect
from django.http import JsonResponse, HttpResponse
from django.views.decorators.csrf import csrf_exempt
from django.urls import reverse
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from django.utils import timezone

from django.db import models
from .models import Payment, PaymentLog, PaymentReceipt
from violations.models import Violation
try:
    from .stripe import (
        create_checkout_session,
        handle_webhook_event,
        get_payment_status,
        create_payment_receipt
    )
except ImportError:
    # If stripe implementation is not available, use our mock wrapper
    from .stripe_wrapper import (
        create_checkout_session,
        handle_webhook_event,
        get_payment_status,
        create_payment_receipt
    )

logger = logging.getLogger('sutms.payments')

@login_required
def payment_dashboard(request):
    """
    Dashboard view for payments.
    Shows list of payments, status, etc.
    """
    # Check user permissions
    user = request.user
    
    # Different views based on user type
    if user.is_admin:
        # Admin sees all payments with stats
        payments = Payment.objects.all().order_by('-created_at')[:20]
        total_payments = Payment.objects.count()
        completed_payments = Payment.objects.filter(status=Payment.PaymentStatus.COMPLETED).count()
        pending_payments = Payment.objects.filter(status=Payment.PaymentStatus.PENDING).count()
        total_amount = Payment.objects.filter(status=Payment.PaymentStatus.COMPLETED).aggregate(
            total=models.Sum('amount')
        )['total'] or 0
    
    elif user.is_officer:
        # Officers see payments for violations they've reported
        payments = Payment.objects.filter(
            violation__reported_by=user
        ).order_by('-created_at')[:20]
        total_payments = Payment.objects.filter(violation__reported_by=user).count()
        completed_payments = Payment.objects.filter(
            violation__reported_by=user,
            status=Payment.PaymentStatus.COMPLETED
        ).count()
        pending_payments = Payment.objects.filter(
            violation__reported_by=user,
            status=Payment.PaymentStatus.PENDING
        ).count()
        total_amount = Payment.objects.filter(
            violation__reported_by=user,
            status=Payment.PaymentStatus.COMPLETED
        ).aggregate(total=models.Sum('amount'))['total'] or 0
        
    else:
        # Vehicle owners see their own payments
        payments = Payment.objects.filter(
            violation__vehicle__owner=user
        ).order_by('-created_at')[:20]
        total_payments = Payment.objects.filter(violation__vehicle__owner=user).count()
        completed_payments = Payment.objects.filter(
            violation__vehicle__owner=user,
            status=Payment.PaymentStatus.COMPLETED
        ).count()
        pending_payments = Payment.objects.filter(
            violation__vehicle__owner=user,
            status=Payment.PaymentStatus.PENDING
        ).count()
        total_amount = Payment.objects.filter(
            violation__vehicle__owner=user,
            status=Payment.PaymentStatus.COMPLETED
        ).aggregate(total=models.Sum('amount'))['total'] or 0
    
    context = {
        'payments': payments,
        'total_payments': total_payments,
        'completed_payments': completed_payments,
        'pending_payments': pending_payments,
        'total_amount': total_amount,
    }
    
    return render(request, 'payments/dashboard.html', context)

@login_required
def payment_list(request):
    """
    List view for payments.
    Shows list of payments for the current user.
    """
    user = request.user
    
    # Filter by status if specified
    status = request.GET.get('status')
    if status and status in dict(Payment.PaymentStatus.choices):
        status_filter = status
    else:
        status_filter = None
    
    # Different filters based on user type
    if user.is_admin:
        payments = Payment.objects.all()
    elif user.is_officer:
        payments = Payment.objects.filter(violation__reported_by=user)
    else:
        payments = Payment.objects.filter(violation__vehicle__owner=user)
    
    # Apply status filter if specified
    if status_filter:
        payments = payments.filter(status=status_filter)
    
    # Order payments
    payments = payments.order_by('-created_at')
    
    context = {
        'payments': payments,
        'status_filter': status_filter,
        'payment_statuses': Payment.PaymentStatus.choices,
    }
    
    return render(request, 'payments/payment_list.html', context)

@login_required
def payment_detail(request, payment_id):
    """
    Detail view for a payment.
    Shows details of a specific payment.
    """
    user = request.user
    
    # Get the payment and check permissions
    payment = get_object_or_404(Payment, id=payment_id)
    
    # Check if user is allowed to view this payment
    if not user.is_admin and not user.is_officer:
        # For vehicle owners, check if they own the vehicle associated with the violation
        if payment.violation.vehicle.owner != user:
            messages.error(request, 'You do not have permission to view this payment.')
            return redirect('payments:dashboard')
    
    # Get payment logs
    logs = payment.logs.order_by('-created_at')
    
    context = {
        'payment': payment,
        'logs': logs,
    }
    
    # Check if the payment has a receipt
    try:
        receipt = payment.receipt
        context['receipt'] = receipt
    except PaymentReceipt.DoesNotExist:
        context['receipt'] = None
    
    return render(request, 'payments/payment_detail.html', context)

@login_required
def pay_violation(request, violation_id):
    """
    View to initiate payment for a violation.
    """
    # Get the violation
    violation = get_object_or_404(Violation, id=violation_id)
    
    # Check permissions
    user = request.user
    if not user.is_admin and not user.is_vehicle_owner:
        messages.error(request, 'You do not have permission to pay for violations.')
        return redirect('violations:violation_detail', violation_id=violation_id)
    
    # For vehicle owners, check if they own the vehicle
    if user.is_vehicle_owner and violation.vehicle.owner != user:
        messages.error(request, 'You can only pay for violations of your own vehicles.')
        return redirect('violations:violation_detail', violation_id=violation_id)
    
    # Check if the violation already has a pending or completed payment
    existing_payment = Payment.objects.filter(
        violation=violation,
        status__in=[Payment.PaymentStatus.PENDING, Payment.PaymentStatus.COMPLETED]
    ).first()
    
    if existing_payment:
        if existing_payment.status == Payment.PaymentStatus.COMPLETED:
            messages.info(request, 'This violation has already been paid.')
            return redirect('payments:payment_detail', payment_id=existing_payment.id)
        else:
            # Redirect to the existing payment
            messages.info(request, 'A payment for this violation is already in progress.')
            return redirect('payments:payment_detail', payment_id=existing_payment.id)
    
    # Process the form submission
    if request.method == 'POST':
        payment_method = request.POST.get('payment_method')
        
        # Create a new payment object
        payment = Payment(
            violation=violation,
            amount=violation.fine_amount,
            payment_method=payment_method,
            paid_by=user,
            due_date=violation.due_date
        )
        payment.save()
        
        # Create payment log
        PaymentLog.objects.create(
            payment=payment,
            type=PaymentLog.LogType.INFO,
            message=f"Payment initiated by {user.get_full_name() or user.username}",
            data={'payment_method': payment_method}
        )
        
        # Process based on payment method
        if payment_method == Payment.PaymentMethod.STRIPE:
            # Redirect to Stripe checkout
            result = create_checkout_session(payment)
            
            if result['success']:
                # Redirect to Stripe checkout
                return redirect(result['checkout_url'])
            else:
                # Handle error
                messages.error(request, f"Error creating payment: {result.get('error', 'Unknown error')}")
                return redirect('violations:violation_detail', violation_id=violation_id)
                
        elif payment_method == Payment.PaymentMethod.BANK_TRANSFER:
            # Redirect to bank transfer details page
            return redirect('payments:payment_bank_transfer', payment_id=payment.id)
            
        elif payment_method == Payment.PaymentMethod.CASH:
            # For cash payments, mark as pending and provide receipt
            payment.status = Payment.PaymentStatus.PENDING
            payment.save()
            
            messages.success(request, 'Cash payment recorded. Please pay at the traffic office.')
            return redirect('payments:payment_detail', payment_id=payment.id)
            
        else:
            # Other payment methods (implement as needed)
            messages.warning(request, f"Payment method '{payment.get_payment_method_display()}' is not fully implemented yet.")
            return redirect('payments:payment_detail', payment_id=payment.id)
    
    # Display the payment form
    context = {
        'violation': violation,
        'payment_methods': Payment.PaymentMethod.choices,
    }
    
    return render(request, 'payments/pay_violation.html', context)

@login_required
def payment_bank_transfer(request, payment_id):
    """
    View for bank transfer payment details.
    """
    payment = get_object_or_404(Payment, id=payment_id)
    
    # Check if payment is for bank transfer
    if payment.payment_method != Payment.PaymentMethod.BANK_TRANSFER:
        messages.error(request, 'This payment is not a bank transfer.')
        return redirect('payments:payment_detail', payment_id=payment_id)
    
    # Get bank details from settings
    bank_details = {
        'name': 'Nepal Traffic Police Bank',
        'account_number': '123456789',
        'branch': 'Kathmandu Main Branch',
        'account_holder': 'Traffic Police Department',
        'reference': f'TRAFV-{payment.id}',
    }
    
    context = {
        'payment': payment,
        'bank_details': bank_details,
    }
    
    return render(request, 'payments/bank_transfer.html', context)

@login_required
def payment_success(request):
    """
    Success page for payments.
    """
    # Get the session ID from the URL
    session_id = request.GET.get('session_id')
    
    if not session_id:
        messages.error(request, 'No session ID provided.')
        return redirect('payments:dashboard')
    
    # Get the payment by session ID
    try:
        payment = Payment.objects.get(stripe_session_id=session_id)
    except Payment.DoesNotExist:
        messages.error(request, 'Payment not found.')
        return redirect('payments:dashboard')
    
    # Check payment status and update if needed
    result = get_payment_status(payment)
    
    context = {
        'payment': payment,
        'session_id': session_id,
    }
    
    return render(request, 'payments/success.html', context)

@login_required
def payment_cancel(request):
    """
    Cancellation page for payments.
    """
    # Get the session ID from the URL
    session_id = request.GET.get('session_id')
    
    if not session_id:
        messages.error(request, 'No session ID provided.')
        return redirect('payments:dashboard')
    
    # Get the payment by session ID
    try:
        payment = Payment.objects.get(stripe_session_id=session_id)
    except Payment.DoesNotExist:
        messages.error(request, 'Payment not found.')
        return redirect('payments:dashboard')
    
    # Mark the payment as cancelled if it's still pending
    if payment.status == Payment.PaymentStatus.PENDING:
        payment.status = Payment.PaymentStatus.CANCELLED
        payment.save()
        
        # Create payment log
        PaymentLog.objects.create(
            payment=payment,
            type=PaymentLog.LogType.FAILURE,
            message="Payment cancelled by user",
            data={'session_id': session_id}
        )
    
    context = {
        'payment': payment,
        'session_id': session_id,
    }
    
    return render(request, 'payments/cancel.html', context)

@login_required
def payment_receipt(request, payment_id):
    """
    View for payment receipt.
    """
    payment = get_object_or_404(Payment, id=payment_id)
    
    # Check permissions
    user = request.user
    if not user.is_admin and not user.is_officer and payment.violation.vehicle.owner != user and payment.paid_by != user:
        messages.error(request, 'You do not have permission to view this receipt.')
        return redirect('payments:dashboard')
    
    # Check if payment is completed
    if payment.status != Payment.PaymentStatus.COMPLETED:
        messages.error(request, 'Receipt is only available for completed payments.')
        return redirect('payments:payment_detail', payment_id=payment_id)
    
    # Get or create the receipt
    try:
        receipt = payment.receipt
    except PaymentReceipt.DoesNotExist:
        receipt = create_payment_receipt(payment)
        
    if not receipt:
        messages.error(request, 'Failed to generate receipt.')
        return redirect('payments:payment_detail', payment_id=payment_id)
    
    # Return PDF if available, otherwise show HTML receipt
    if receipt.pdf_file:
        response = HttpResponse(receipt.pdf_file.read(), content_type='application/pdf')
        response['Content-Disposition'] = f'inline; filename="{receipt.receipt_number}.pdf"'
        return response
    
    context = {
        'payment': payment,
        'receipt': receipt,
        'receipt_data': json.loads(receipt.receipt_data) if receipt.receipt_data else {},
    }
    
    return render(request, 'payments/receipt.html', context)

@csrf_exempt
def stripe_webhook(request):
    """
    Webhook endpoint for Stripe.
    """
    payload = request.body
    sig_header = request.META.get('HTTP_STRIPE_SIGNATURE')
    event = None

    try:
        event_data = {
            'payload': payload,
            'stripe_signature': sig_header
        }
        
        # Handle the event
        success = handle_webhook_event(event_data)
        
        if success:
            return HttpResponse(status=200)
        else:
            return HttpResponse(status=400)
    except Exception as e:
        logger.error(f"Error handling Stripe webhook: {str(e)}")
        return HttpResponse(status=400)

@login_required
def payment_status_api(request, payment_id):
    """
    API view to check payment status.
    """
    payment = get_object_or_404(Payment, id=payment_id)
    
    # Check permissions
    user = request.user
    if not user.is_admin and not user.is_officer and payment.violation.vehicle.owner != user and payment.paid_by != user:
        return JsonResponse({'error': 'Permission denied'}, status=403)
    
    # For Stripe payments, check status with Stripe
    if payment.payment_method == Payment.PaymentMethod.STRIPE and payment.stripe_session_id:
        result = get_payment_status(payment)
        
        if result['success']:
            return JsonResponse({
                'status': payment.status,
                'status_display': payment.get_status_display(),
                'stripe_status': result.get('stripe_status', ''),
                'updated': True,
            })
        else:
            return JsonResponse({
                'status': payment.status,
                'status_display': payment.get_status_display(),
                'error': result.get('error', 'Unknown error'),
                'updated': False,
            })
    
    # For other payment methods
    return JsonResponse({
        'status': payment.status,
        'status_display': payment.get_status_display(),
        'updated': False,
    })

@login_required
def mark_payment_as_completed(request, payment_id):
    """
    View for officers to mark cash or bank transfer payments as completed.
    """
    payment = get_object_or_404(Payment, id=payment_id)
    
    # Check permissions
    if not request.user.is_admin and not request.user.is_officer:
        messages.error(request, 'You do not have permission to update payment status.')
        return redirect('payments:payment_detail', payment_id=payment_id)
    
    # Check if payment can be marked as completed
    if payment.status != Payment.PaymentStatus.PENDING:
        messages.error(request, f'Only pending payments can be marked as completed. Current status: {payment.get_status_display()}')
        return redirect('payments:payment_detail', payment_id=payment_id)
    
    if payment.payment_method not in [Payment.PaymentMethod.CASH, Payment.PaymentMethod.BANK_TRANSFER, Payment.PaymentMethod.OTHER]:
        messages.error(request, f'Only cash, bank transfer, or other payments can be manually marked as completed. Current method: {payment.get_payment_method_display()}')
        return redirect('payments:payment_detail', payment_id=payment_id)
    
    # Process form submission
    if request.method == 'POST':
        transaction_id = request.POST.get('transaction_id', '')
        notes = request.POST.get('notes', '')
        
        # Update payment status
        payment.status = Payment.PaymentStatus.COMPLETED
        payment.transaction_id = transaction_id
        payment.payment_date = timezone.now()
        payment.notes += f"\n{notes}" if payment.notes else notes
        payment.processed_by = request.user
        payment.save()
        
        # Log the action
        PaymentLog.objects.create(
            payment=payment,
            type=PaymentLog.LogType.SUCCESS,
            message=f"Payment marked as completed by {request.user.get_full_name() or request.user.username}",
            data={'transaction_id': transaction_id, 'notes': notes}
        )
        
        messages.success(request, 'Payment has been marked as completed.')
        return redirect('payment_detail', payment_id=payment.id)
    
    context = {
        'payment': payment,
    }
    
    return render(request, 'payments/mark_completed.html', context)