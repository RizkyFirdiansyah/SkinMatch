import 'package:flutter/material.dart';

import '../../../core/utils/validators.dart';
import '../theme/auth_style.dart';
import 'auth_primary_button.dart';
import 'auth_text_field.dart';

/// Isi tab "Daftar Akun Baru".
class RegisterForm extends StatefulWidget {
  /// Dipanggil saat pendaftaran berhasil (untuk pindah ke tab Masuk).
  final VoidCallback onRegistered;

  const RegisterForm({super.key, required this.onRegistered});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _agree = false;
  bool _agreeError = false;
  bool _isLoading = false;
  String _password = '';

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Nilai kekuatan sandi 0 sampai 4.
  int _strength(String p) {
    int score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score;
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _agreeError = !_agree);
    if (!formOk || !_agree) return;

    setState(() => _isLoading = true);
    // Nanti: ganti dengan panggilan API registrasi ke server.
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Akun berhasil dibuat. Silakan masuk.'),
        backgroundColor: AuthColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    widget.onRegistered();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          AuthTextField(
            label: 'Nama Lengkap *',
            hint: 'Nama sesuai identitas Anda',
            icon: Icons.badge_outlined,
            controller: _nameController,
            textInputAction: TextInputAction.next,
            validator: (v) => Validators.requiredField(v, 'Nama lengkap'),
          ),
          const SizedBox(height: 14),
          AuthTextField(
            label: 'Email / No. Handphone *',
            hint: 'nama@email.com atau 08123456789',
            icon: Icons.mail_outline,
            controller: _idController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: Validators.emailOrPhone,
          ),
          const SizedBox(height: 14),
          AuthTextField(
            label: 'Kata Sandi *',
            hint: 'Minimal 8 karakter & kombinasi unik',
            icon: Icons.lock_outline,
            controller: _passwordController,
            isPassword: true,
            textInputAction: TextInputAction.next,
            validator: Validators.newPassword,
            onChanged: (v) => setState(() => _password = v),
          ),
          _buildStrengthMeter(),
          const SizedBox(height: 14),
          AuthTextField(
            label: 'Konfirmasi Kata Sandi *',
            hint: 'Ketik ulang kata sandi',
            icon: Icons.lock_reset_outlined,
            controller: _confirmController,
            isPassword: true,
            textInputAction: TextInputAction.done,
            validator: (v) {
              if (v == null || v.isEmpty) {
                return 'Konfirmasi kata sandi wajib diisi';
              }
              if (v != _passwordController.text) return 'Kata sandi tidak sama';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildAgreeRow(),
          const SizedBox(height: 18),
          AuthPrimaryButton(
            text: 'Daftar Akun',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  /// Batang kekuatan sandi (4 kotak kecil + tulisan).
  Widget _buildStrengthMeter() {
    if (_password.isEmpty) return const SizedBox.shrink();

    final int s = _strength(_password);
    const labels = ['Lemah', 'Lemah', 'Sedang', 'Baik', 'Kuat'];
    const colors = [
      AuthColors.danger,
      AuthColors.danger,
      AuthColors.strengthMedium,
      AuthColors.strengthGood,
      AuthColors.primary,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(4, (i) {
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 5,
                    margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: i < s ? colors[s] : AuthColors.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            labels[s],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors[s],
            ),
          ),
        ],
      ),
    );
  }

  /// Centang "Saya menyetujui ..."
  Widget _buildAgreeRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _agree,
                activeColor: AuthColors.primary,
                side: BorderSide(
                  color: _agreeError ? AuthColors.danger : AuthColors.textGrey,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                onChanged: (v) => setState(() {
                  _agree = v ?? false;
                  if (_agree) _agreeError = false;
                }),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: AuthColors.textGrey,
                    ),
                    children: [
                      TextSpan(text: 'Saya menyetujui '),
                      TextSpan(
                        text: 'Ketentuan Layanan',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AuthColors.textDark,
                        ),
                      ),
                      TextSpan(text: ' & '),
                      TextSpan(
                        text: 'Kebijakan Privasi Data Medis Kulit',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AuthColors.textDark,
                        ),
                      ),
                      TextSpan(text: ' SkinMatch.'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_agreeError)
          const Padding(
            padding: EdgeInsets.only(left: 32, top: 4),
            child: Text(
              'Anda harus menyetujui terlebih dahulu',
              style: TextStyle(fontSize: 11, color: AuthColors.danger),
            ),
          ),
      ],
    );
  }
}