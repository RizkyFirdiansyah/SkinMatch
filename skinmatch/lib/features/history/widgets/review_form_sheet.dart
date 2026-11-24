import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/models/skinmatch_models.dart';

typedef ReviewFormSubmit = Future<bool> Function(
  int rating,
  bool cocok,
  String comment,
);
typedef ReviewFormDelete = Future<bool> Function();

class ReviewFormSheet extends StatefulWidget {
  const ReviewFormSheet({
    super.key,
    required this.item,
    required this.initialCocok,
    required this.initialRating,
    required this.initialComment,
    required this.onSubmit,
    this.onDelete,
  });

  final ProductHistoryItem item;
  final bool initialCocok;
  final int? initialRating;
  final String initialComment;
  final ReviewFormSubmit onSubmit;
  final ReviewFormDelete? onDelete;

  @override
  State<ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<ReviewFormSheet> {
  late bool _cocok;
  late int _rating;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _cocok = widget.initialCocok;
    _rating = widget.initialRating ?? 0;
    _commentController = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.8,
        child: SafeArea(
          top: false,
          child: Material(
            color: AppColors.backgroundSoft,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                  child: _buildHeader(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildVerdictSelector(),
                        const SizedBox(height: 18),
                        Text(
                          'Beri nilai',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStars(),
                        const SizedBox(height: 14),
                        Text(
                          _cocok
                              ? 'Apa yang kamu rasakan?'
                              : 'Masalah apa yang muncul?',
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!_cocok) ...[
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.statusWarningBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Jika reaksi berlanjut, hentikan pemakaian dan konsultasikan ke dokter kulit.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.statusWarningDark,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: _commentController,
                          minLines: 3,
                          maxLines: 3,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: _cocok
                                ? 'Ceritakan pengalamanmu (opsional)'
                                : 'Ceritakan apa yang terjadi (opsional)',
                            filled: true,
                            fillColor: AppColors.cardSurface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.borderLight,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppColors.borderLight,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _rating == 0 || _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cocok
                            ? AppColors.primarySage
                            : AppColors.statusDanger,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.borderLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              widget.item.review == null
                                  ? 'Kirim Ulasan'
                                  : 'Simpan Perubahan',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                ),
                if (widget.onDelete != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextButton.icon(
                      onPressed: _isSubmitting ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus Ulasan'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.statusDanger,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.item.scanResult.brand,
                style: AppTypography.badgeText.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                widget.item.scanResult.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Dipindai ${widget.item.scanResult.timestamp}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Tutup form ulasan',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(LucideIcons.x, size: 18),
        ),
      ],
    );
  }

  Widget _buildVerdictSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.statusSafeBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _VerdictOption(
              label: 'Cocok',
              selected: _cocok,
              selectedColor: AppColors.primarySage,
              onTap: () => setState(() => _cocok = true),
            ),
          ),
          Expanded(
            child: _VerdictOption(
              label: 'Masalah',
              selected: !_cocok,
              selectedColor: AppColors.statusDanger,
              onTap: () => setState(() => _cocok = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars() {
    return Row(
      children: List.generate(5, (index) {
        final rating = index + 1;
        return IconButton(
          tooltip: '$rating bintang',
          onPressed: () => setState(() => _rating = rating),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          icon: Icon(
            Icons.star,
            size: 28,
            color: rating <= _rating
                ? const Color(0xFFF59E0B)
                : AppColors.borderLight,
          ),
        );
      }),
    );
  }

  Future<void> _submit() async {
    if (_rating == 0 || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    late final bool saved;
    try {
      saved = await widget.onSubmit(_rating, _cocok, _commentController.text);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;
    if (saved) Navigator.of(context).pop(true);
  }

  Future<void> _confirmDelete() async {
    final onDelete = widget.onDelete;
    if (onDelete == null || _isSubmitting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.statusDangerBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.statusDanger,
                  size: 26,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Hapus ulasan ini?',
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ulasan untuk ${widget.item.scanResult.productName} akan dihapus permanen. Produk akan kembali berstatus Belum Direview.',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusSafeBg,
                        foregroundColor: AppColors.primaryDark,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusDanger,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text('Hapus'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    late final bool deleted;
    try {
      deleted = await onDelete();
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
    if (!mounted) return;
    if (deleted) Navigator.of(context).pop(true);
  }
}

class _VerdictOption extends StatelessWidget {
  const _VerdictOption({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
