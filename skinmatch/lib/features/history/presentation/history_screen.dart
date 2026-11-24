import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/skinmatch_models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/history_list_item.dart';
import '../widgets/review_form_sheet.dart';

// ── History Filter ─────────────────────────────────────────────────────────────
enum HistoryFilter { all, cocok, tidakCocok }

final historyFilterProvider = StateProvider<HistoryFilter>((ref) => HistoryFilter.all);

// ── History Screen ─────────────────────────────────────────────────────────────

/// /history — Riwayat & Review Produk
/// Sesuai PRD Section 2E: Search, filter chips, stats card, multi-state cards
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchController = TextEditingController();
  final Map<String, int> _quickRatings = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductHistoryItem> _filterItems(
    List<ProductHistoryItem> items,
    HistoryFilter filter,
    String query,
  ) {
    var filtered = items.where((item) {
      if (query.isEmpty) return true;
      return item.scanResult.productName
              .toLowerCase()
              .contains(query.toLowerCase()) ||
          item.scanResult.brand
              .toLowerCase()
              .contains(query.toLowerCase());
    }).toList();

    return switch (filter) {
      HistoryFilter.cocok => filtered
          .where((i) => i.scanResult.verdict.isSuitable)
          .toList(),
      HistoryFilter.tidakCocok => filtered
          .where((i) => !i.scanResult.verdict.isSuitable)
          .toList(),
      HistoryFilter.all => filtered,
    };
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(scanHistoryProvider);
    return history.when(
      data: (items) => _buildHistory(context, items),
      loading: () => const Scaffold(
        backgroundColor: AppColors.backgroundSoft,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        backgroundColor: AppColors.backgroundSoft,
        appBar: SkinMatchAppBar(title: 'Riwayat Pindai'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(scanHistoryProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(
    BuildContext context,
    List<ProductHistoryItem> allItems,
  ) {
    final filter = ref.watch(historyFilterProvider);
    final items =
        _filterItems(allItems, filter, _searchController.text);

    final scanned = allItems.length;
    final cocok = allItems
        .where((i) => i.scanResult.verdict.isSuitable)
        .length;
    final tidakCocok = scanned - cocok;

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: SkinMatchAppBar(
        title: 'Riwayat Pindai',
        subtitle: '$scanned produk dipindai',
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.sliders_horizontal),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Column(
              children: [
                // ── Search Bar ─────────────────────────────────────────────
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Cari produk atau bahan...',
                    prefixIcon: const Icon(LucideIcons.search,
                        size: 18, color: AppColors.textSecondary),
                    hintStyle: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textTertiary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Icon(LucideIcons.x,
                                size: 16, color: AppColors.textSecondary),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Filter Chips ───────────────────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Semua',
                        isSelected: filter == HistoryFilter.all,
                        onTap: () => ref
                            .read(historyFilterProvider.notifier)
                            .state = HistoryFilter.all,
                      ),
                      _FilterChip(
                        label: 'Cocok',
                        isSelected: filter == HistoryFilter.cocok,
                        onTap: () => ref
                            .read(historyFilterProvider.notifier)
                            .state = HistoryFilter.cocok,
                      ),
                      _FilterChip(
                        label: 'Tidak Cocok',
                        isSelected: filter == HistoryFilter.tidakCocok,
                        variant: _ChipVariant.danger,
                        onTap: () => ref
                            .read(historyFilterProvider.notifier)
                            .state = HistoryFilter.tidakCocok,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Dermatological Stats Card ──────────────────────────────
                _StatsCard(
                  scanned: scanned,
                  cocok: cocok,
                  tidakCocok: tidakCocok,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // ── Product List ───────────────────────────────────────────────────
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.search_x,
                            size: 40, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada produk ditemukan',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    itemCount: items.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: HistoryListItem(
                        item: items[i],
                        onTap: () => context.push(
                          AppRoutes.analysisPath(items[i].scanResult.scanId),
                        ),
                        onMarkGood: () =>
                            _showReviewForm(items[i], initialCocok: true),
                        onMarkBad: () =>
                            _showReviewForm(items[i], initialCocok: false),
                        selectedRating: _quickRatings[items[i].historyId],
                        onRatingSelected: (rating) {
                          setState(() {
                            _quickRatings[items[i].historyId] = rating;
                          });
                          _showReviewForm(
                            items[i],
                            initialCocok:
                                items[i].review?.confirmedMatch ?? true,
                            initialRating: rating,
                            initialComment: items[i].review?.userNotes ?? '',
                          );
                        },
                        onEditReview: () => _showReviewForm(
                          items[i],
                          initialCocok: items[i].review?.confirmedMatch ?? true,
                          initialRating: items[i].review?.rating.round(),
                          initialComment: items[i].review?.userNotes ?? '',
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewForm(
    ProductHistoryItem item, {
    required bool initialCocok,
    int? initialRating,
    String initialComment = '',
  }) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReviewFormSheet(
        item: item,
        initialCocok: initialCocok,
        initialRating: initialRating ?? _quickRatings[item.historyId],
        initialComment: initialComment,
        onSubmit: (rating, cocok, comment) => _submitReview(
          item.scanResult.scanId,
          rating: rating,
          cocok: cocok,
          comment: comment,
        ),
        onDelete: item.review == null
            ? null
            : () => _deleteReview(item.scanResult.scanId),
      ),
    );
  }

  Future<bool> _submitReview(
    String scanId, {
    required int rating,
    required bool cocok,
    required String comment,
  }) async {
    try {
      await ref
          .read(apiClientProvider)
          .saveScanReview(
            scanId: scanId,
            rating: rating,
            cocok: cocok,
            comment: comment,
          );
      if (!mounted) return false;
      ref.invalidate(scanHistoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ulasan berhasil disimpan.')),
      );
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }

  Future<bool> _deleteReview(String scanId) async {
    try {
      await ref.read(apiClientProvider).deleteScanReview(scanId: scanId);
      if (!mounted) return false;
      _quickRatings.remove(scanId);
      ref.invalidate(scanHistoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ulasan berhasil dihapus.')),
      );
      return true;
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return false;
    }
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.scanned,
    required this.cocok,
    required this.tidakCocok,
  });

  final int scanned;
  final int cocok;
  final int tidakCocok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, Color(0xFF2D5440)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatItem(
              value: '$scanned',
              label: 'Dipindai',
              icon: LucideIcons.scan_line,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              value: '$cocok',
              label: 'Cocok',
              icon: Icons.check_circle_outline,
              color: AppColors.primarySage,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              value: '$tidakCocok',
              label: 'Tidak Cocok',
              icon: Icons.cancel_outlined,
              color: AppColors.statusDanger,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    this.color = Colors.white,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        // Gunakan FittedBox agar teks tidak turun baris atau error saat layar sempit
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: AppTypography.headingMedium.copyWith(color: Colors.white),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: Colors.white54,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      // Gunakan withOpacity pengganti withValues
      color: Colors.white.withValues(alpha: 0.15),
    );
  }
}

enum _ChipVariant { normal, danger }

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.variant = _ChipVariant.normal,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final _ChipVariant variant;

  @override
  Widget build(BuildContext context) {
    final activeColor = variant == _ChipVariant.danger
        ? AppColors.statusDanger
        : AppColors.primarySage;
    final activeBg = variant == _ChipVariant.danger
        ? AppColors.statusDangerBg
        : AppColors.statusSafeBg;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderLight,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: isSelected ? activeColor : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
