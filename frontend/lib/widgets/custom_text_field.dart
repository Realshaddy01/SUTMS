import 'package:flutter/material.dart';
import 'form_input_field.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? labelText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final bool enabled;
  final String? helperText;

  const CustomTextField({
    Key? key,
    required this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.enabled = true,
    this.helperText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FormInputField(
      controller: controller,
      hintText: hintText ?? labelText ?? 'Enter text',
      labelText: labelText,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixIcon: suffixIcon,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      enabled: enabled,
      helperText: helperText,
      onChanged: onChanged,
    );
  }
}
