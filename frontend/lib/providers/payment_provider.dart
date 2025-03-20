import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:sutms/services/api_service.dart';

class PaymentProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;

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
      
      final apiService = ApiService();
      
      // 1. Create payment intent on the server
      final paymentIntent = await apiService.createPaymentIntent(
        amount,
        currency,
        violationId,
      );
      
      if (paymentIntent['client_secret'] == null) {
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
      final success = await apiService.confirmPayment(
        violationId,
        paymentIntent['id'],
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
}

