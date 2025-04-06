class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }
  
  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    
    // Check for at least one uppercase letter, one lowercase letter, and one number
    final hasUppercase = value.contains(RegExp(r'[A-Z]'));
    final hasLowercase = value.contains(RegExp(r'[a-z]'));
    final hasNumber = value.contains(RegExp(r'[0-9]'));
    
    if (!hasUppercase || !hasLowercase || !hasNumber) {
      return 'Password must contain uppercase, lowercase, and number';
    }
    
    return null;
  }
  
  // Phone number validation for Nepal
  static String? validateNepaliPhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }
    
    // Nepal phone numbers: usually 10 digits starting with 9
    final phoneRegex = RegExp(r'^9[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid Nepali phone number';
    }
    
    return null;
  }
  
  // Nepali license plate validation
  static String? validateNepaliLicensePlate(String? value) {
    if (value == null || value.isEmpty) {
      return 'License plate is required';
    }
    
    // Format examples: "Ba 2 Pa 1234" or "Ba 2 Kha 1234"
    final plateRegex = RegExp(r'^[A-Z][a-z]\s+\d+\s+[A-Z][a-z]\s+\d+$');
    if (!plateRegex.hasMatch(value)) {
      return 'Please enter a valid Nepali license plate format';
    }
    
    return null;
  }
  
  // Name validation
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    
    if (value.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    
    return null;
  }
  
  // Required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    return null;
  }
}
