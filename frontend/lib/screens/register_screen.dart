import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/loading_indicator.dart';
import '../utils/validators.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  
  // Vehicle Owner specific controllers
  final _citizenshipNumberController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _addressController = TextEditingController();
  
  // Traffic Officer specific controllers
  final _badgeNumberController = TextEditingController();
  final _departmentController = TextEditingController();
  final _jurisdictionController = TextEditingController();
  
  String _selectedUserType = 'vehicle_owner';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _citizenshipNumberController.dispose();
    _phoneNumberController.dispose();
    _addressController.dispose();
    _badgeNumberController.dispose();
    _departmentController.dispose();
    _jurisdictionController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
        return;
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final Map<String, dynamic> registrationData = {
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'email': _emailController.text.trim(),
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'userType': _selectedUserType,
      };
      
      // Add user type specific fields
      if (_selectedUserType == 'vehicle_owner') {
        registrationData.addAll({
          'citizenshipNumber': _citizenshipNumberController.text.trim(),
          'phoneNumber': _phoneNumberController.text.trim(),
          'address': _addressController.text.trim(),
        });
      } else if (_selectedUserType == 'traffic_officer') {
        registrationData.addAll({
          'badgeNumber': _badgeNumberController.text.trim(),
          'department': _departmentController.text.trim(),
          'jurisdiction': _jurisdictionController.text.trim(),
        });
      }

      final success = await authProvider.register(
        username: registrationData['username'],
        password: registrationData['password'],
        email: registrationData['email'],
        firstName: registrationData['firstName'],
        lastName: registrationData['lastName'],
        userType: registrationData['userType'],
        citizenshipNumber: registrationData['citizenshipNumber'],
        phoneNumber: registrationData['phoneNumber'],
        address: registrationData['address'],
        badgeNumber: registrationData['badgeNumber'],
        department: registrationData['department'],
        jurisdiction: registrationData['jurisdiction'],
      );

      if (success && mounted) {
        // Navigate based on user type
        if (authProvider.userType == 'traffic_officer') {
          Navigator.pushReplacementNamed(context, '/officer');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: SafeArea(
        child: authProvider.isLoading
            ? const LoadingIndicator(message: 'Creating account...')
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (authProvider.error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              authProvider.error!,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        
                        // Account Type Selection
                        const Text(
                          'Account Type',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Vehicle Owner'),
                                value: 'vehicle_owner',
                                groupValue: _selectedUserType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedUserType = value!;
                                  });
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Traffic Officer'),
                                value: 'traffic_officer',
                                groupValue: _selectedUserType,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedUserType = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Basic Information
                        const Text(
                          'Basic Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CustomTextField(
                          controller: _usernameController,
                          labelText: 'Username',
                          prefixIcon: Icons.person,
                          validator: Validators.validateUsername,
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _emailController,
                          labelText: 'Email',
                          prefixIcon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: CustomTextField(
                                controller: _firstNameController,
                                labelText: 'First Name',
                                prefixIcon: Icons.person_outline,
                                validator: Validators.validateRequired,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: CustomTextField(
                                controller: _lastNameController,
                                labelText: 'Last Name',
                                prefixIcon: Icons.person_outline,
                                validator: Validators.validateRequired,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _passwordController,
                          labelText: 'Password',
                          prefixIcon: Icons.lock,
                          obscureText: !_isPasswordVisible,
                          validator: Validators.validatePassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomTextField(
                          controller: _confirmPasswordController,
                          labelText: 'Confirm Password',
                          prefixIcon: Icons.lock,
                          obscureText: !_isConfirmPasswordVisible,
                          validator: (value) {
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isConfirmPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() {
                                _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // User Type Specific Fields
                        if (_selectedUserType == 'vehicle_owner') ...[
                          const Text(
                            'Vehicle Owner Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _citizenshipNumberController,
                            labelText: 'Citizenship Number',
                            prefixIcon: Icons.badge,
                            validator: Validators.validateRequired,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _phoneNumberController,
                            labelText: 'Phone Number',
                            prefixIcon: Icons.phone,
                            keyboardType: TextInputType.phone,
                            validator: Validators.validatePhone,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _addressController,
                            labelText: 'Address',
                            prefixIcon: Icons.location_on,
                            validator: Validators.validateRequired,
                          ),
                        ],
                        
                        if (_selectedUserType == 'traffic_officer') ...[
                          const Text(
                            'Traffic Officer Details',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomTextField(
                            controller: _badgeNumberController,
                            labelText: 'Badge Number',
                            prefixIcon: Icons.badge,
                            validator: Validators.validateRequired,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _departmentController,
                            labelText: 'Department',
                            prefixIcon: Icons.business,
                            validator: Validators.validateRequired,
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _jurisdictionController,
                            labelText: 'Jurisdiction',
                            prefixIcon: Icons.location_city,
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Register',
                          onPressed: _register,
                          isLoading: authProvider.isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text('Already have an account? Login'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
