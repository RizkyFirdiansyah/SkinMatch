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

  bool _isLoading = false;
  bool _sent = false; // false = tampil form, true = tampil "berhasil terkirim"

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    // Nanti: ganti dengan panggilan API "lupa kata sandi" ke server.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _sent = true;
    });
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
                    child: _sent ? _buildSuccess() : _buildForm(),
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
          'Tenang, itu hal biasa. Masukkan email atau No. Handphone yang terdaftar, dan kami kirimkan tautan untuk mengatur ulang kata sandi Anda.',
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
            label: 'Email / No. Handphone *',
            hint: 'nama@email.com atau 08123456789',
            icon: Icons.mail_outline,
            controller: _idController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: Validators.emailOrPhone,
          ),
        ),
        const SizedBox(height: 20),
        AuthPrimaryButton(
          text: 'Kirim Tautan Reset',
          isLoading: _isLoading,
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

  Widget _buildSuccess() {
    return Column(
      key: const ValueKey('success'),
      children: [
        // Ikon centang yang "membal" saat muncul
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: _iconCircle(Icons.mark_email_read_outlined),
        ),
        const SizedBox(height: 20),
        const Text(
          'Tautan Terkirim!',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Silakan cek ${_idController.text.trim()} dan ikuti petunjuk di dalamnya untuk membuat kata sandi baru.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: AuthColors.textGrey,
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(text: 'Kembali ke Masuk', onPressed: _back),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _sent = false),
          child: const Text(
            'Belum menerima? Kirim ulang',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AuthColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}