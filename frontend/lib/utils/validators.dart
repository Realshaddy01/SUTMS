class Validators {
  // Username validation
  static String? validateUsername(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < 3) {
      return '$fieldName must be at least 3 characters';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return '$fieldName must contain only letters, numbers, and underscore';
    }
    return null;
  }

  // Adapter for FormInputField
  static String? validateUsernameAdapter(String? value) {
    return validateUsername(value, 'Username');
  }

  // Email validation
  static String? validateEmail(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Adapter for FormInputField
  static String? validateEmailAdapter(String? value) {
    return validateEmail(value, 'Email');
  }

  // Password validation
  static String? validatePassword(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < 8) {
      return '$fieldName must be at least 8 characters';
    }
    return null;
  }

  // Adapter for FormInputField
  static String? validatePasswordAdapter(String? value) {
    return validatePassword(value, 'Password');
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String password, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  // Adapter for FormInputField
  static String? validateRequiredAdapter(String? value) {
    return validateRequired(value, 'Field');
  }

  // Phone number validation
  static String? validatePhone(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (!RegExp(r'^\+?[0-9]{10,15}$').hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // Adapter for FormInputField
  static String? validatePhoneAdapter(String? value) {
    return validatePhone(value, 'Phone number');
  }

  // License plate validation
  static String? validateLicensePlate(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    if (value.length < 2 || value.length > 15) {
      return '$fieldName must be between 2 and 15 characters';
    }
    return null;
  }

  // Adapter for FormInputField
  static String? validateLicensePlateAdapter(String? value) {
    return validateLicensePlate(value, 'License plate');
  }

  // Year validation
  static String? validateYear(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    final year = int.tryParse(value);
    if (year == null) {
      return 'Please enter a valid year';
    }
    
    final currentYear = DateTime.now().year;
    if (year < 1900 || year > currentYear + 1) {
      return 'Please enter a year between 1900 and ${currentYear + 1}';
    }
    
    return null;
  }

  // Adapter for FormInputField
  static String? validateYearAdapter(String? value) {
    return validateYear(value, 'Year');
  }

  // Numeric validation
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    if (!RegExp(r'^\d+$').hasMatch(value)) {
      return '$fieldName must contain only numbers';
    }
    
    return null;
  }

  // Adapter for FormInputField
  static String? validateNumericAdapter(String? value) {
    return validateNumeric(value, 'Number');
  }

  // Double validation
  static String? validateDouble(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    
    final double? number = double.tryParse(value);
    if (number == null) {
      return 'Please enter a valid number';
    }
    
    return null;
  }

  // Adapter for FormInputField
  static String? validateDoubleAdapter(String? value) {
    return validateDouble(value, 'Number');
  }

  // Adapter for FormInputField
  static String? Function(String?) validateConfirmPasswordAdapter(String password) {
    return (String? value) => validateConfirmPassword(value, password, 'Confirm Password');
  }
}
