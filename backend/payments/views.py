import stripe
from django.conf import settings
from rest_framework import views, permissions, status
from rest_framework.response import Response
from .models import Payment
from violations.models import Violation
from django.utils import timezone

stripe.api_key = settings.STRIPE_SECRET_KEY

class CreatePaymentIntentView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            # Get data from request
            amount = request.data.get('amount')
            currency = request.data.get('currency', 'usd')
            violation_id = request.data.get('violation_id')
            
            # Validate data
            if not amount or not violation_id:
                return Response(
                    {'error': 'Amount and violation_id are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get violation
            try:
                violation = Violation.objects.get(id=violation_id)
            except Violation.DoesNotExist:
                return Response(
                    {'error': 'Violation not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Check if violation belongs to user
            if violation.vehicle.owner != request.user:
                return Response(
                    {'error': 'You are not authorized to pay for this violation'},
                    status=status.HTTP_403_FORBIDDEN
                )
            
            # Create customer if not exists
            customer = None
            if request.user.email:
                customers = stripe.Customer.list(email=request.user.email)
                if customers.data:
                    customer = customers.data[0]
                else:
                    customer = stripe.Customer.create(
                        email=request.user.email,
                        name=f"{request.user.first_name} {request.user.last_name}",
                    )
            
            # Create ephemeral key
            ephemeral_key = stripe.EphemeralKey.create(
                customer=customer.id,
                stripe_version='2023-10-16',
            )
            
            # Create payment intent
            payment_intent = stripe.PaymentIntent.create(
                amount=int(float(amount)),
                currency=currency,
                customer=customer.id,
                automatic_payment_methods={'enabled': True},
                metadata={
                    'violation_id': violation_id,
                    'user_id': request.user.id,
                },
            )
            
            # Create payment record
            payment = Payment.objects.create(
                violation=violation,
                user=request.user,
                amount=float(amount) / 100,  # Convert cents to dollars
                payment_intent_id=payment_intent.id,
                status='pending',
            )
            
            return Response({
                'client_secret': payment_intent.client_secret,
                'ephemeral_key': ephemeral_key.secret,
                'customer': customer.id,
                'id': payment_intent.id,
            })
            
        except stripe.error.StripeError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

class ConfirmPaymentView(views.APIView):
    permission_classes = [permissions.IsAuthenticated]
    
    def post(self, request):
        try:
            # Get data from request
            violation_id = request.data.get('violation_id')
            payment_intent_id = request.data.get('payment_intent_id')
            
            # Validate data
            if not violation_id or not payment_intent_id:
                return Response(
                    {'error': 'violation_id and payment_intent_id are required'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
            # Get violation
            try:
                violation = Violation.objects.get(id=violation_id)
            except Violation.DoesNotExist:
                return Response(
                    {'error': 'Violation not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Get payment
            try:
                payment = Payment.objects.get(
                    violation=violation,
                    payment_intent_id=payment_intent_id,
                )
            except Payment.DoesNotExist:
                return Response(
                    {'error': 'Payment not found'},
                    status=status.HTTP_404_NOT_FOUND
                )
            
            # Retrieve payment intent from Stripe
            payment_intent = stripe.PaymentIntent.retrieve(payment_intent_id)
            
            # Check payment status
            if payment_intent.status == 'succeeded':
                # Update payment status
                payment.status = 'completed'
                payment.save()
                
                # Update violation status
                violation.is_paid = True
                violation.payment_date = timezone.now()
                violation.status = 'resolved'
                violation.save()
                
                return Response({'status': 'Payment successful'})
            else:
                return Response(
                    {'error': f'Payment not successful. Status: {payment_intent.status}'},
                    status=status.HTTP_400_BAD_REQUEST
                )
            
        except stripe.error.StripeError as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return Response(
                {'error': str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

