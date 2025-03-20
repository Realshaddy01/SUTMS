import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sutms/utils/api_constants.dart';

class PaymentProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  Map<String, dynamic>? _paymentIntent;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<bool> makePayment({
    required String amount,
    required String currency,
    required String token,
    required int violationId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Create payment intent on the server
      final paymentIntent = await _createPaymentIntent(
        amount: amount,
        currency: currency,
        token: token,
        violationId: violationId,
      );

      if (paymentIntent == null) {
        _error = 'Failed to create payment intent';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // 2. Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'SUTMS',
          customerId: paymentIntent['customer'],
          customerEphemeralKeySecret: paymentIntent['ephemeral_key'],
          style: ThemeMode.light,
        ),
      );

      // 3. Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // 4. Confirm payment on the server
      final success = await _confirmPayment(
        token: token,
        violationId: violationId,
        paymentIntentId: paymentIntent['id'],
      );

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      if (e is StripeException) {
        _error = '${e.error.localizedMessage}';
      } else {
        _error = e.toString();
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> _createPaymentIntent({
    required String amount,
    required String currency,
    required String token,
    required int violationId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/payments/create-payment-intent/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'amount': amount,
          'currency': currency,
          'violation_id': violationId,
        }),
      );

      if (response.statusCode == 200) {
        _paymentIntent = json.decode(response.body);
        return _paymentIntent;
      } else {
        _error = 'Failed to create payment intent: ${response.body}';
        return null;
      }
    } catch (e) {
      _error = 'Error creating payment intent: $e';
      return null;
    }
  }

  Future<bool> _confirmPayment({
    required String token,
    required int violationId,
    required String paymentIntentId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/payments/confirm-payment/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Token $token',
        },
        body: json.encode({
          'violation_id': violationId,
          'payment_intent_id': paymentIntentId,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        _error = 'Failed to confirm payment: ${response.body}';
        return false;
      }
    } catch (e) {
      _error = 'Error confirming payment: $e';
      return false;
    }
  }
}

