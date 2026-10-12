import 'package:flutter/material.dart';

import '../theme/auth_style.dart';

/// Kolom isian dengan judul di atasnya.
/// Kalau isPassword = true, otomatis ada ikon mata.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    this.controller,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _hidden = true;

  OutlineInputBorder _border(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.isPassword && _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          validator: widget.validator,
          onChanged: widget.onChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle:
                const TextStyle(fontSize: 12, color: AuthColors.textGrey),
            errorStyle: const TextStyle(fontSize: 11),
            prefixIcon:
                Icon(widget.icon, size: 20, color: AuthColors.textGrey),
            suffixIcon: widget.isPassword
                ? IconButton(
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AuthColors.textGrey,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
            filled: true,
            fillColor: AuthColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
            border: _border(AuthColors.border),
            enabledBorder: _border(AuthColors.border),
            focusedBorder: _border(AuthColors.primary, 1.5),
            errorBorder: _border(AuthColors.danger),
            focusedErrorBorder: _border(AuthColors.danger, 1.5),
          ),
        ),
      ],
    );
  }
}