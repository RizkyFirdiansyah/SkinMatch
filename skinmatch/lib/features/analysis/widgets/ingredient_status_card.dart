import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/models/skinmatch_models.dart';

/// Card untuk satu bahan INCI dalam hasil analisis
/// Sesuai PRD Section 2D: Color-coded category tags
class IngredientStatusCard extends StatelessWidget {
  const IngredientStatusCard({super.key, required this.ingredient});

  final IngredientItem ingredient;

  @override
  Widget build(BuildContext context) {
    final (tagBg, tagText, icon) = switch (ingredient.category) {
      IngredientSafetyCategory.hero => (
          AppColors.tagHeroBg,
          AppColors.tagHeroText,
          LucideIcons.circle_check,
        ),
      IngredientSafetyCategory.safeCarrier => (
          AppColors.tagSafeBg,
          AppColors.tagSafeText,
          LucideIcons.circle_check,
        ),
      IngredientSafetyCategory.warning => (
          AppColors.tagWarningBg,
          AppColors.tagWarningText,
          LucideIcons.triangle_alert,
        ),
      IngredientSafetyCategory.irritant => (
          AppColors.tagDangerBg,
          AppColors.tagDangerText,
          LucideIcons.circle_minus,
        ),
    };

    final categoryLabel = switch (ingredient.category) {
      IngredientSafetyCategory.hero => 'HERO',
      IngredientSafetyCategory.safeCarrier => 'AMAN',
      IngredientSafetyCategory.warning => 'PERHATIAN',
      IngredientSafetyCategory.irritant => 'IRITAN',
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderMuted),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: tagText),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Expanded dipertahankan agar nama bahan memenuhi sisa ruang
                    Expanded(
                      child: Text(
                        ingredient.cleanName,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (ingredient.concentration != null) ...[
                      const SizedBox(width: 8),
                      // Expanded dihapus pada konsentrasi untuk mencegah overflow
                      Text(
                        ingredient.concentration!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ingredient.functionDescription,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (ingredient.warningNote != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    ingredient.warningNote!,
                    style: AppTypography.bodySmall.copyWith(
                      color: tagText,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Category badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tagBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              categoryLabel,
              style: AppTypography.badgeText.copyWith(color: tagText),
            ),
          ),
        ],
      ),
    );
  }
}