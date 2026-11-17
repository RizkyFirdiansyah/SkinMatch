import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routing/app_router.dart';
import '../theme/auth_style.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: Stack(
        children: [
          const Positioned(
            top: -110,
            right: -100,
            child: _WelcomeGlow(size: 300),
          ),
          const Positioned(
            bottom: 80,
            left: -150,
            child: _WelcomeGlow(size: 280),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const _WelcomeBrand(),
                          const Spacer(flex: 4),
                          const _ScanIllustration(),
                          const SizedBox(height: 18),
                          Text(
                            'Kenali skincare yang cocok untuk kulitmu',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontSize: 26,
                                  height: 1.18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Pindai komposisi produk, lalu temukan '
                            'kecocokannya dengan profil kulitmu.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  height: 1.55,
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 24),
                          const Spacer(flex: 2),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => context.go(AppRoutes.auth),
                              child: const Text('Mulai Sekarang'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _showTutorial(context),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppColors.statusSafeBg,
                                side: BorderSide.none,
                                foregroundColor: AppColors.primaryDark,
                              ),
                              child: const Text('Lihat Tutorial'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.auth),
                            child: const Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                ),
                                children: [
                                  TextSpan(text: 'Sudah punya akun? '),
                                  TextSpan(
                                    text: 'Masuk',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showTutorial(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.58),
      builder: (dialogContext) => _TutorialDialog(
        onStart: () {
          Navigator.of(dialogContext).pop();
          context.go(AppRoutes.auth);
        },
      ),
    );
  }
}

class _WelcomeBrand extends StatelessWidget {
  const _WelcomeBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AuthColors.primary.withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(Icons.eco, color: AuthColors.primary, size: 22),
        ),
        const SizedBox(width: 10),
        Text(
          'SkinMatch',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AuthColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _ScanIllustration extends StatelessWidget {
  const _ScanIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 224,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 250,
            height: 210,
            decoration: BoxDecoration(
              color: AppColors.statusSafeBg,
              borderRadius: BorderRadius.circular(32),
            ),
          ),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.backgroundSoft,
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          Container(
            width: 184,
            height: 154,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 14,
                      color: AppColors.primarySage,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'INGREDIENTS',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  'Aqua, Glycerin',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Niacinamide, Panthenol',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Centella Asiatica',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 58,
            right: 58,
            top: 119,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF61D5A5),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF61D5A5).withValues(alpha: 0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog({required this.onStart});

  final VoidCallback onStart;

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _step = 0;

  static const _steps = [
    (
      title: 'Isi profil kulitmu',
      description:
          'Pilih tipe kulit dan bahan yang ingin dihindari. Hasil scan akan '
          'disesuaikan dengan profilmu.',
      icon: Icons.tune_rounded,
    ),
    (
      title: 'Pindai daftar bahan',
      description:
          'Arahkan kamera ke label komposisi (INCI). Pastikan teks terlihat '
          'jelas atau pilih foto dari galeri.',
      icon: Icons.document_scanner_outlined,
    ),
    (
      title: 'Baca hasilnya',
      description:
          'Lihat match score, bahan kunci, dan bahan yang perlu diwaspadai. '
          'Simpan produk ke riwayat untuk membandingkannya nanti.',
      icon: Icons.insights_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];

    return Dialog(
      backgroundColor: AppColors.backgroundSoft,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'LANGKAH ${_step + 1} DARI ${_steps.length}',
                  style: const TextStyle(
                    color: AppColors.primaryDark,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.65,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Tutup tutorial',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 132,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.statusSafeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    step.icon,
                    size: 42,
                    color: AppColors.primarySage,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              step.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              step.description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _steps.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: index == _step ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: index == _step
                        ? AppColors.primarySage
                        : AppColors.borderLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: AppColors.statusSafeBg,
                      side: BorderSide.none,
                      foregroundColor: AppColors.primaryDark,
                    ),
                    child: const Text('Lewati'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: FilledButton(
                    onPressed: _step < _steps.length - 1
                        ? () => setState(() => _step++)
                        : widget.onStart,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: Text(
                      _step < _steps.length - 1 ? 'Lanjut' : 'Mulai Sekarang',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeGlow extends StatelessWidget {
  const _WelcomeGlow({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              AppColors.primarySageLight.withValues(alpha: 0.16),
              AppColors.primarySageLight.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
