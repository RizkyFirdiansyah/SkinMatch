import 'package:flutter/material.dart';

/// JANGAN gunakan Color() langsung, selalu pakai AppColors.
abstract class AppColors {
  // ── Primary Brand ──────────────────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF1F382B);
  static const Color primarySage = Color(0xFF4E7D5B);
  static const Color primarySageLight = Color(0xFF5C8374);

  // ── Background & Surface ───────────────────────────────────────────────────
  static const Color backgroundSoft = Color(0xFFF7F9F6);
  static const Color backgroundClean = Color(0xFFF3F4F1);
  static const Color cardSurface = Color(0xFFFFFFFF);

  // ── Status / Semantic ──────────────────────────────────────────────────────
  /// Match Score ≥ 80% — Aman / Low Risk
  static const Color statusSafe = Color(0xFF4E7D5B);
  static const Color statusSafeBg = Color(0xFFE8F0EA);

  /// Match Score 60–79% — Perlu Patch Test / Moderate
  static const Color statusWarning = Color(0xFFD97706);
  static const Color statusWarningDark = Color(0xFFB45309);
  static const Color statusWarningBg = Color(0xFFFEF3C7);

  /// Match Score < 60% — Tidak Disarankan / High Risk
  static const Color statusDanger = Color(0xFFDC2626);
  static const Color statusDangerBg = Color(0xFFFEE2E2);

  // ── Neutral / Text ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1F382B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ── Border & Divider ───────────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderMuted = Color(0xFFF0F0EE);

  // ── Ingredient Tag Colors ──────────────────────────────────────────────────
  /// Hero Ingredients (Niacinamide, Ceramide, Centella)
  static const Color tagHeroBg = Color(0xFFD1FAE5);
  static const Color tagHeroText = Color(0xFF065F46);

  /// Safe Carrier Ingredients
  static const Color tagSafeBg = Color(0xFFF3F4F1);
  static const Color tagSafeText = Color(0xFF374151);

  /// Warning / Alergen Ingredients
  static const Color tagWarningBg = Color(0xFFFEF3C7);
  static const Color tagWarningText = Color(0xFF92400E);

  /// Irritant Ingredients
  static const Color tagDangerBg = Color(0xFFFEE2E2);
  static const Color tagDangerText = Color(0xFF991B1B);

  // ── Shadow ─────────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get buttonGlow => [
    BoxShadow(
      color: primarySage.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
