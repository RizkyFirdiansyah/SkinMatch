import 'package:flutter/material.dart';

import '../../../shared/widgets/fade_slide_in.dart';
import '../theme/auth_style.dart';
import '../widgets/auth_background.dart';
import '../widgets/auth_brand_header.dart';
import '../widgets/login_form.dart';
import '../widgets/register_form.dart';

/// Layar utama autentikasi.
/// Mode Masuk atau Daftar dipilih lewat tombol di bawah form.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// Mode yang sedang tampil di layar.
  bool _isLogin = true;

  /// Mode yang terakhir diminta pengguna (untuk menangani ketukan beruntun).
  bool _target = true;

  /// Isi terlihat atau sedang memudar.
  bool _visible = true;

  /// Penanda supaya ketukan cepat tidak saling bertabrakan.
  int _switchId = 0;

  /// Urutan: (1) isi lama memudar -> (2) isi diganti, tinggi menyesuaikan
  /// -> (3) isi baru muncul. Total sekitar 300 ms.
  Future<void> _switchMode(bool login) async {
    if (login == _target) return;
    _target = login;
    final int id = ++_switchId;

    // 1. Isi lama memudar
    setState(() => _visible = false);
    await Future.delayed(const Duration(milliseconds: 90));
    if (!mounted || id != _switchId) return;

    // 2. Ganti isi saat tidak terlihat; kotak membesar/mengecil halus
    setState(() => _isLogin = login);
    await Future.delayed(const Duration(milliseconds: 60));
    if (!mounted || id != _switchId) return;

    // 3. Isi baru muncul
    setState(() => _visible = true);
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: FadeSlideIn(
          child: Column(
            children: [
              const AuthBrandHeader(),
              const SizedBox(height: 24),

              // Kotak yang tingginya berubah halus
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.none,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: Duration(milliseconds: _visible ? 150 : 90),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    // Saat memudar, isi tidak bisa diketuk
                    ignoring: !_visible,
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        children: [
                          _buildHeading(),
                          const SizedBox(height: 20),
                          _isLogin
                              ? const LoginForm(key: ValueKey('login'))
                              : RegisterForm(
                                  key: const ValueKey('register'),
                                  onRegistered: () => _switchMode(true),
                                ),
                          const SizedBox(height: 18),
                          _buildSwitchButton(),
                          if (_isLogin) ...[
                            const SizedBox(height: 16),
                            _buildTerms(),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Judul kecil yang menjelaskan mode yang sedang tampil.
  Widget _buildHeading() {
    return Column(
      children: [
        Text(
          _isLogin ? 'Selamat Datang' : 'Buat Akun Baru',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AuthColors.textDark,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isLogin
              ? 'Masuk untuk melanjutkan analisis skincare Anda.'
              : 'Lengkapi data berikut untuk mulai menggunakan SkinMatch.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AuthColors.textGrey,
          ),
        ),
      ],
    );
  }

  /// Tombol bawah: "Belum punya akun? Daftar Disini" / "Sudah punya akun? Masuk"
  Widget _buildSwitchButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AuthColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AuthColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _switchMode(!_isLogin),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLogin ? 'Belum punya akun? ' : 'Sudah punya akun? ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AuthColors.textGrey,
                  ),
                ),
                Text(
                  _isLogin ? 'Daftar Disini' : 'Masuk',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AuthColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AuthColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTerms() {
    return const Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 10, height: 1.5, color: AuthColors.textGrey),
        children: [
          TextSpan(text: 'Dengan masuk atau mendaftar, Anda menyetujui '),
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
          TextSpan(text: ' kami.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}