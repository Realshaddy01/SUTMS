import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sutms/models/violation.dart';
import 'package:sutms/providers/auth_provider.dart';
import 'package:sutms/providers/payment_provider.dart';
import 'package:sutms/utils/app_theme.dart';
import 'package:sutms/widgets/custom_button.dart';

class PaymentScreen extends StatefulWidget {
  final Violation violation;

  const PaymentScreen({
    Key? key,
    required this.violation,
  }) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final paymentProvider = Provider.of<PaymentProvider>(context);
    
    // Convert fine amount to cents for Stripe
    final amountInCents = (widget.violation.fine! * 100).toInt().toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Fine'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Violation Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Vehicle', widget.violation.vehicleLicensePlate),
                    const Divider(),
                    _buildInfoRow('Violation', widget.violation.violationTypeName),
                    const Divider(),
                    _buildInfoRow('Date', widget.violation.formattedDate),
                    const Divider(),
                    _buildInfoRow('Time', widget.violation.formattedTime),
                    const Divider(),
                    _buildInfoRow(
                      'Fine Amount',
                      '\$${widget.violation.fine!.toStringAsFixed(2)}',
                      valueColor: Colors.red,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: Row(
                        children: [
                          Image.asset(
                            'assets/images/stripe.png',
                            width: 60,
                            height: 30,
                          ),
                          const SizedBox(width: 8),
                          const Text('Credit/Debit Card'),
                        ],
                      ),
                      value: 'stripe',
                      groupValue: 'stripe', // Only one option for now
                      onChanged: (value) {},
                    ),
                    const Divider(),
                    const Text(
                      'Your payment information is processed securely. We do not store your credit card details.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (paymentProvider.error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  paymentProvider.error!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
            CustomButton(
              text: 'Pay \$${widget.violation.fine!.toStringAsFixed(2)}',
              isLoading: paymentProvider.isLoading,
              onPressed: () async {
                final success = await paymentProvider.makePayment(
                  amount: amountInCents,
                  currency: 'usd',
                  token: authProvider.token!,
                  violationId: widget.violation.id,
                );
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Payment successful'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop(true); // Return success
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

