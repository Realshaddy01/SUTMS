import 'package:intl/intl.dart';

class CurrencyFormatter {
  // Format currency with symbol
  static String format(double amount, {String currencyCode = 'NPR'}) {
    if (currencyCode == 'NPR') {
      // Nepali Rupee format
      final formatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: 'NPR ',
        decimalDigits: 2,
      );
      return formatter.format(amount);
    } else {
      // Default international format
      final formatter = NumberFormat.currency(
        locale: 'en_US',
        symbol: '$currencyCode ',
        decimalDigits: 2,
      );
      return formatter.format(amount);
    }
  }
  
  // Format currency without symbol
  static String formatWithoutSymbol(double amount, {int decimalDigits = 2}) {
    final formatter = NumberFormat.decimalPattern();
    formatter.minimumFractionDigits = decimalDigits;
    formatter.maximumFractionDigits = decimalDigits;
    return formatter.format(amount);
  }
  
  // Format compact currency (e.g., 1.2K, 3.5M)
  static String formatCompact(double amount) {
    final formatter = NumberFormat.compact();
    return formatter.format(amount);
  }
}
