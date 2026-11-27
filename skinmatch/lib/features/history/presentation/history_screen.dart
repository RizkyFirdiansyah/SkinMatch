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

// ── History Filter ─────────────────────────────────────────────────────────────
enum HistoryFilter { all, match, notMatch }

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
      HistoryFilter.match => filtered
          .where((i) => i.scanResult.matchScore >= 80)
          .toList(),
      HistoryFilter.notMatch => filtered
          .where((i) => i.scanResult.matchScore < 80)
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

    // Stats
    final scanned = allItems.length;
    final matched = allItems.where((i) => i.scanResult.matchScore >= 80).length;
    final warnings = allItems
        .where((i) => i.scanResult.safetyStatus != SafetyStatus.lowRisk)
        .length;
    final matchPct = scanned > 0 ? (matched / scanned * 100).round() : 0;

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
                        label: 'Sangat Cocok',
                        isSelected: filter == HistoryFilter.match,
                        onTap: () => ref
                            .read(historyFilterProvider.notifier)
                            .state = HistoryFilter.match,
                      ),
                      _FilterChip(
                        label: 'Perlu Perhatian',
                        isSelected: filter == HistoryFilter.notMatch,
                        variant: _ChipVariant.danger,
                        onTap: () => ref
                            .read(historyFilterProvider.notifier)
                            .state = HistoryFilter.notMatch,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Dermatological Stats Card ──────────────────────────────
                _StatsCard(
                  scanned: scanned,
                  matchPct: matchPct,
                  matched: matched,
                  warnings: warnings,
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
                        onMarkGood: () => _showReviewNotAvailable(context),
                        onMarkBad: () => _showReviewNotAvailable(context),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showReviewNotAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur ulasan belum tersedia di server.')),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.scanned,
    required this.matchPct,
    required this.matched,
    required this.warnings,
  });

  final int scanned;
  final int matchPct;
  final int matched;
  final int warnings;

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
              label: 'Dipindai\n(30 hari)',
              icon: LucideIcons.scan_line,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              value: '$matchPct%',
              label: 'Sesuai\nProfil',
              icon: LucideIcons.percent,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              value: '$matched',
              label: 'Cocok\nAman',
              icon: LucideIcons.shield_check,
              color: AppColors.primarySage,
            ),
          ),
          _VerticalDivider(),
          Expanded(
            child: _StatItem(
              value: '$warnings',
              label: 'Ada\nPeringatan',
              icon: LucideIcons.triangle_alert,
              color: AppColors.statusWarning,
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