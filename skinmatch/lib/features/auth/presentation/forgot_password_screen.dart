import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../theme/auth_style.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_primary_button.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  /// Kembali ke layar sebelumnya. Kalau tidak ada, ke layar Auth.
  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.auth);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur reset kata sandi belum tersedia di server.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: Column(
        children: [
          // Tombol kembali
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
              child: Material(
                color: AuthColors.surface,
                shape: const CircleBorder(
                  side: BorderSide(color: AuthColors.border),
                ),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _back,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FadeSlideIn(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _buildForm(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Bulatan besar berisi ikon, dipakai di dua tampilan.
  Widget _iconCircle(IconData icon) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AuthColors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AuthColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(icon, size: 40, color: AuthColors.primary),
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('form'),
      children: [
        _iconCircle(Icons.lock_reset_rounded),
        const SizedBox(height: 20),
        const Text(
          'Lupa Kata Sandi?',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Masukkan email yang terdaftar untuk mengatur ulang kata sandi Anda.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AuthColors.textGrey,
          ),
        ),
        const SizedBox(height: 24),
        Form(
          key: _formKey,
          child: AuthTextField(
            label: 'Email *',
            hint: 'nama@email.com',
            icon: Icons.mail_outline,
            controller: _idController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.email,
          ),
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          text: 'Kirim Tautan Reset',
          onPressed: _submit,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _back,
          child: const Text(
            'Kembali ke Masuk',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AuthColors.primary,
            ),
          ),
        ),
      ],
    );
  }

}