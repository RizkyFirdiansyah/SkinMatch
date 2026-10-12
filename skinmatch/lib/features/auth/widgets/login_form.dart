import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/utils/validators.dart';
import '../theme/auth_style.dart';
import 'auth_primary_button.dart';
import 'auth_text_field.dart';

/// Isi tab "Masuk".
class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Periksa isian dulu. Kalau ada yang salah, berhenti di sini.
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // Nanti: ganti dengan panggilan API login ke server.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() => _isLoading = false);

    context.go(AppRoutes.scan); // masuk ke aplikasi utama
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AuthTextField(
            label: 'Email / No. Handphone *',
            hint: 'nama@email.com atau 08123456789',
            icon: Icons.mail_outline,
            controller: _idController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: Validators.emailOrPhone,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Kata Sandi *',
            hint: 'Minimal 8 karakter & kombinasi unik',
            icon: Icons.lock_outline,
            controller: _passwordController,
            isPassword: true,
            textInputAction: TextInputAction.done,
            validator: (v) => Validators.requiredField(v, 'Kata sandi'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _rememberMe,
                  activeColor: AuthColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
              ),
              const SizedBox(width: 8),
              const Text('Ingat saya', style: TextStyle(fontSize: 12)),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(AppRoutes.forgotPassword),
                child: const Text(
                  'Lupa Kata Sandi?',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AuthColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            text: 'Masuk',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}