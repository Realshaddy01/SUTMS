class Payment {
  final int id;
  final int violationId;
  final Map<String, dynamic>? violationDetails;
  final int userId;
  final String? userName;
  final double amount;
  final String currency;
  final String paymentMethod;
  final String? paymentMethodDisplay;
  final String paymentStatus;
  final String? paymentStatusDisplay;
  final String? transactionId;
  final String? stripePaymentIntentId;
  final String? stripeSessionId;
  final String? receiptUrl;
  final String? receiptNumber;
  final String? paymentDate;
  final String? failureReason;
  final bool isTestPayment;
  final String createdAt;
  final String updatedAt;

  Payment({
    required this.id,
    required this.violationId,
    this.violationDetails,
    required this.userId,
    this.userName,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    this.paymentMethodDisplay,
    required this.paymentStatus,
    this.paymentStatusDisplay,
    this.transactionId,
    this.stripePaymentIntentId,
    this.stripeSessionId,
    this.receiptUrl,
    this.receiptNumber,
    this.paymentDate,
    this.failureReason,
    required this.isTestPayment,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor to create a Payment from JSON
  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      violationId: json['violation'],
      violationDetails: json['violation_details'],
      userId: json['user'],
      userName: json['user_name'],
      amount: json['amount'].toDouble(),
      currency: json['currency'],
      paymentMethod: json['payment_method'],
      paymentMethodDisplay: json['payment_method_display'],
      paymentStatus: json['payment_status'],
      paymentStatusDisplay: json['payment_status_display'],
      transactionId: json['transaction_id'],
      stripePaymentIntentId: json['stripe_payment_intent_id'],
      stripeSessionId: json['stripe_session_id'],
      receiptUrl: json['receipt_url'],
      receiptNumber: json['receipt_number'],
      paymentDate: json['payment_date'],
      failureReason: json['failure_reason'],
      isTestPayment: json['is_test_payment'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  // Convert Payment to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'violation': violationId,
      'violation_details': violationDetails,
      'user': userId,
      'user_name': userName,
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod,
      'payment_method_display': paymentMethodDisplay,
      'payment_status': paymentStatus,
      'payment_status_display': paymentStatusDisplay,
      'transaction_id': transactionId,
      'stripe_payment_intent_id': stripePaymentIntentId,
      'stripe_session_id': stripeSessionId,
      'receipt_url': receiptUrl,
      'receipt_number': receiptNumber,
      'payment_date': paymentDate,
      'failure_reason': failureReason,
      'is_test_payment': isTestPayment,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}
