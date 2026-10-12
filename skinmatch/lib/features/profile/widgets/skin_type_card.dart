import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/models/skinmatch_models.dart';

/// Custom Radio Card untuk pemilihan tipe kulit
/// Sesuai PRD Section 2B: Single select, clinical description
class SkinTypeCard extends StatelessWidget {
  const SkinTypeCard({
    super.key,
    required this.skinType,
    required this.isSelected,
    required this.onTap,
  });

  final BiologicalSkinType skinType;
  final bool isSelected;
  final VoidCallback onTap;

  static const _icons = {
    BiologicalSkinType.normal: LucideIcons.droplets,
    BiologicalSkinType.dry: LucideIcons.cloud_off,
    BiologicalSkinType.combination: LucideIcons.git_branch,
    BiologicalSkinType.oily: LucideIcons.droplet,
    BiologicalSkinType.sensitive: LucideIcons.triangle_alert,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icons[skinType] ?? LucideIcons.circle_question_mark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.statusSafeBg : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primarySage : AppColors.borderLight,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? AppColors.cardShadow : null,
        ),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySage
                    : AppColors.backgroundClean,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? AppColors.textOnDark
                    : AppColors.textSecondary,
              ),
            ),

            const SizedBox(width: 14),

            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skinType.label.toUpperCase(),
                    style: AppTypography.labelLarge.copyWith(
                      color: isSelected
                          ? AppColors.primarySage
                          : AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    skinType.description,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primarySage
                      : AppColors.borderLight,
                  width: isSelected ? 5 : 2,
                ),
                color: isSelected
                    ? AppColors.primarySage
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Center(
                      child: Icon(
                        Icons.circle,
                        size: 6,
                        color: AppColors.textOnDark,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
