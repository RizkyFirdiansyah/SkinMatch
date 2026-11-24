import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/models/skinmatch_models.dart';

/// Multi-state product card untuk layar Riwayat
/// Sesuai PRD Section 2E: Reviewed (positive), Breakout, Unreviewed/Quick-rate
class HistoryListItem extends StatelessWidget {
  const HistoryListItem({
    super.key,
    required this.item,
    required this.onTap,
    required this.onMarkGood,
    required this.onMarkBad,
    required this.selectedRating,
    required this.onRatingSelected,
    required this.onEditReview,
  });

  final ProductHistoryItem item;
  final VoidCallback onTap;
  final VoidCallback onMarkGood;
  final VoidCallback onMarkBad;
  final int? selectedRating;
  final ValueChanged<int> onRatingSelected;
  final VoidCallback onEditReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.scanResult.brand,
                        style: AppTypography.badgeText.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.scanResult.productName,
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.scanResult.timestamp,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.scanResult.verdict.label,
                        style: AppTypography.labelSmall.copyWith(
                          color: item.scanResult.verdict.isSuitable
                              ? AppColors.statusSafe
                              : AppColors.statusDanger,
                        ),
                      ),
                    ],
                  ),
                ),

                // Status badge
                _StatusPill(status: item.trialStatus),
              ],
            ),
          ),

          // ── Review (if exists) ──────────────────────────────────────────
          if (item.review != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderMuted),
            const SizedBox(height: 12),
            _ReviewSection(review: item.review!, onEdit: onEditReview),
          ],

          // ── AI Feedback Loop notification ──────────────────────────────
          if (item.trialStatus == TrialStatus.triggeredBreakout &&
              item.aiFeedbackApplied) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusWarningBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.brain,
                    size: 14,
                    color: AppColors.statusWarningDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'AI Feedback Loop: Filter bahan pemicu telah diperketat untuk profil Anda',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.statusWarningDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Quick Rating (unreviewed) ───────────────────────────────────
          if (item.trialStatus == TrialStatus.unreviewed) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderMuted),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  LucideIcons.circle_question_mark,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Bagaimana hasilnya di kulitmu?',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Spacer(),
                _QuickRateButton(
                  label: 'Cocok',
                  icon: LucideIcons.thumbs_up,
                  color: AppColors.statusSafe,
                  bg: AppColors.statusSafeBg,
                  onTap: onMarkGood,
                ),
                const SizedBox(width: 8),
                _QuickRateButton(
                  label: 'Masalah',
                  icon: LucideIcons.thumbs_down,
                  color: AppColors.statusDanger,
                  bg: AppColors.statusDangerBg,
                  onTap: onMarkBad,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Beri nilai',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                ...List.generate(5, (index) {
                  final rating = index + 1;
                  return IconButton(
                    tooltip: 'Beri nilai $rating bintang',
                    onPressed: () => onRatingSelected(rating),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    icon: Icon(
                      Icons.star,
                      size: 20,
                      color: rating <= (selectedRating ?? 0)
                          ? const Color(0xFFF59E0B)
                          : AppColors.borderLight,
                    ),
                  );
                }),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color get _borderColor {
    return switch (item.trialStatus) {
      TrialStatus.completedSuccess => AppColors.primarySage.withValues(
        alpha: 0.3,
      ),
      TrialStatus.triggeredBreakout => AppColors.statusDanger.withValues(
        alpha: 0.3,
      ),
      _ => AppColors.borderMuted,
    };
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final TrialStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, text) = switch (status) {
      TrialStatus.completedSuccess => (
        'Cocok',
        AppColors.statusSafeBg,
        AppColors.statusSafe,
      ),
      TrialStatus.triggeredBreakout => (
        'Masalah',
        AppColors.statusDangerBg,
        AppColors.statusDanger,
      ),
      TrialStatus.testingPatch => (
        'Patch Test',
        AppColors.statusWarningBg,
        AppColors.statusWarningDark,
      ),
      TrialStatus.unreviewed => (
        'Belum Direview',
        AppColors.backgroundClean,
        AppColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: AppTypography.badgeText.copyWith(color: text)),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.review, required this.onEdit});
  final ProductReview review;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ...List.generate(5, (i) {
              return Icon(
                Icons.star,
                size: 14,
                color: i < review.rating.floor()
                    ? const Color(0xFFF59E0B)
                    : AppColors.borderLight,
              );
            }),
            const SizedBox(width: 6),
            Text(
              review.rating.toStringAsFixed(1),
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '"${review.userNotes}"',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onEdit,
            child: Text(
              'Edit ulasan',
              style: AppTypography.labelMedium.copyWith(
                color: AppColors.primarySage,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickRateButton extends StatelessWidget {
  const _QuickRateButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: AppTypography.labelSmall.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}
