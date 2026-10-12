import 'package:flutter/material.dart';

import '../theme/auth_style.dart';

/// Bagian atas layar login: logo, lencana, nama, dan deskripsi.
class AuthBrandHeader extends StatelessWidget {
  const AuthBrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: AuthColors.surface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AuthColors.primary.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.eco, size: 38, color: AuthColors.primary),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AuthColors.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AuthColors.border),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 7, color: AuthColors.primary),
              SizedBox(width: 6),
              Text(
                'DERMATOLOGIST VERIFIED AI',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: AuthColors.textGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'SkinMatch',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            color: AuthColors.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Personalisasi Analisis Keamanan Skincare\nBerbasis AI & OCR',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: AuthColors.textGrey,
          ),
        ),
      ],
    );
  }
}