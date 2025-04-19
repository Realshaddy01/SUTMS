import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/violation_provider.dart';
import '../services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final int violationId;

  const PaymentScreen({
    Key? key,
    required this.violationId,
  }) : super(key: key);

  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  String? _error;
  final _apiService = ApiService();
  
  Future<void> _initiatePayment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Create checkout session
      final response = await _apiService.createCheckoutSession(widget.violationId);
      
      if (response['checkout_url'] != null) {
        // Launch checkout URL
        final Uri url = Uri.parse(response['checkout_url']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          
          // Show success dialog after returning from payment
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                title: const Text('Payment Status'),
                content: const Text(
                  'Your payment is being processed. Please check the violation status for updates.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                      
                      // Refresh violation details
                      Provider.of<ViolationProvider>(context, listen: false)
                        .getViolationDetails(widget.violationId);
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        } else {
          setState(() {
            _error = 'Could not launch payment page';
          });
        }
      } else {
        setState(() {
          _error = response['error'] ?? 'Failed to create payment session';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Fine'),
      ),
      body: Consumer<ViolationProvider>(
        builder: (context, provider, child) {
          final violation = provider.selectedViolation;
          
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (violation == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 60,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Violation details not found',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      provider.getViolationDetails(widget.violationId);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          if (violation.finePaid == true) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 60,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This fine has already been paid',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Back'),
                  ),
                ],
              ),
            );
          }
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Payment summary card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildSummaryRow('License Plate', violation.licensePlate ?? 'Not available'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Violation Type', violation.violationTypeName ?? 'Not available'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Date', violation.timestamp.isNotEmpty ? 
                          violation.timestamp.substring(0, 10) : 'Not available'),
                        const SizedBox(height: 8),
                        _buildSummaryRow('Location', violation.location ?? 'Not available'),
                        const Divider(),
                        const SizedBox(height: 8),
                        _buildSummaryRow(
                          'Fine Amount',
                          'NPR ${violation.fineAmount.toStringAsFixed(2)}',
                          isHighlighted: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Payment methods
                const Text(
                  'Payment Methods',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Payment method cards
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildPaymentMethodCard(
                      'Credit/Debit Card',
                      Icons.credit_card,
                      Colors.blue,
                      isSelected: true,
                    ),
                    _buildPaymentMethodCard(
                      'eSewa',
                      Icons.account_balance_wallet,
                      Colors.green,
                    ),
                    _buildPaymentMethodCard(
                      'Khalti',
                      Icons.mobile_friendly,
                      Colors.purple,
                    ),
                    _buildPaymentMethodCard(
                      'Connect IPS',
                      Icons.account_balance,
                      Colors.orange,
                    ),
                  ],
                ),
                
                const Spacer(),
                
                // Error message
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Pay button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _initiatePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Pay Now',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isHighlighted = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            fontSize: isHighlighted ? 18 : 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodCard(String title, IconData icon, Color color, {bool isSelected = false}) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected ? color : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isSelected)
            Icon(
              Icons.check_circle,
              color: color,
              size: 16,
            ),
        ],
      ),
    );
  }
}
