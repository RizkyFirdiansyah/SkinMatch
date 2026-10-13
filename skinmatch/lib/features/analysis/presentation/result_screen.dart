import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/skinmatch_models.dart';
import '../widgets/circular_score.dart';
import '../widgets/ingredient_status_card.dart';

// ── Mock Data Provider ────────────────────────────────────────────────────────
final scanResultProvider =
    Provider.family<ScanAnalysisResult, String>((ref, scanId) {
  return _mockResult;
});

final _mockResult = ScanAnalysisResult(
  scanId: 'demo-scan-001',
  userId: 'user-001',
  timestamp: 'Hari ini, 10:45',
  brand: 'PURE BOTANICA',
  productName: 'Hydra-Calm Barrier Serum 30ml',
  volume: '30ml',
  matchScore: 88,
  safetyStatus: SafetyStatus.lowRisk,
  allergyPotential: AllergyPotential.veryLow,
  comedogenicScale: '0-1',
  formulaPh: '5.5 (Ideal)',
  keyWarning:
      'Mengandung Phenoxyethanol & Fragrance Alami 0.05% — Lakukan patch test jika sedang iritasi aktif',
  routineRecommendation:
      'Formula ini ramah untuk skin barrier bertipe Kombinasi & Sensitif. Gunakan setelah toner, sebelum pelembab.',
  ingredients: const [
    IngredientItem(
      id: 'niacinamide',
      inciName: 'NIACINAMIDE',
      cleanName: 'Niacinamide 2.0%',
      concentration: '2.0%',
      category: IngredientSafetyCategory.hero,
      comedogenicRating: 0,
      irritancyRating: 0,
      functionDescription: 'Mencerahkan & meratakan warna kulit',
    ),
    IngredientItem(
      id: 'centella',
      inciName: 'CENTELLA ASIATICA EXTRACT',
      cleanName: 'Centella Asiatica',
      category: IngredientSafetyCategory.hero,
      comedogenicRating: 0,
      irritancyRating: 0,
      functionDescription: 'Menenangkan & mempercepat regenerasi barrier',
    ),
    IngredientItem(
      id: 'ceramide',
      inciName: 'CERAMIDE NP',
      cleanName: 'Ceramide NP',
      category: IngredientSafetyCategory.hero,
      comedogenicRating: 0,
      irritancyRating: 0,
      functionDescription: 'Memperkuat skin barrier & retensi hidrasi',
    ),
    IngredientItem(
      id: 'aqua',
      inciName: 'AQUA',
      cleanName: 'Air (Aqua)',
      category: IngredientSafetyCategory.safeCarrier,
      comedogenicRating: 0,
      irritancyRating: 0,
      functionDescription: 'Pelarut utama formulasi',
    ),
    IngredientItem(
      id: 'glycerin',
      inciName: 'GLYCERIN',
      cleanName: 'Glycerin',
      category: IngredientSafetyCategory.safeCarrier,
      comedogenicRating: 0,
      irritancyRating: 0,
      functionDescription: 'Humektan, menarik & mengikat air ke kulit',
    ),
    IngredientItem(
      id: 'butylene',
      inciName: 'BUTYLENE GLYCOL',
      cleanName: 'Butylene Glycol',
      category: IngredientSafetyCategory.safeCarrier,
      comedogenicRating: 1,
      irritancyRating: 0,
      functionDescription: 'Pelarut & kondisioner kulit',
    ),
    IngredientItem(
      id: 'fragrance',
      inciName: 'PARFUM',
      cleanName: 'Parfum / Aroma Botanikal 0.05%',
      concentration: '0.05%',
      category: IngredientSafetyCategory.warning,
      comedogenicRating: 0,
      irritancyRating: 1,
      functionDescription: 'Pewangi botanikal konsentrasi rendah',
      warningNote: 'Potensi alergen pada kulit sensitif',
    ),
  ],
);

// ── Result Screen ─────────────────────────────────────────────────────────────

/// /analysis/:id — Scan Analysis Result Screen
/// Sesuai PRD Section 2D: Match Score gauge, ingredient breakdown tabs, warnings
class ResultScreen extends ConsumerStatefulWidget {
  const ResultScreen({super.key, required this.scanId});
  final String scanId;

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(scanResultProvider(widget.scanId));
    final heroIngredients = result.ingredients
        .where((i) => i.category == IngredientSafetyCategory.hero)
        .toList();
    final warningIngredients = result.ingredients
        .where((i) =>
            i.category == IngredientSafetyCategory.warning ||
            i.category == IngredientSafetyCategory.irritant)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // ── Product Hero SliverAppBar ────────────────────────────────
              _ProductHeroAppBar(result: result),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Match Score + Safety Status ──────────────────────
                      _MatchScoreCard(result: result),
                      const SizedBox(height: 16),

                      // ── Key Warning Card ─────────────────────────────────
                      if (result.keyWarning != null)
                        _KeyWarningCard(warning: result.keyWarning!),
                      const SizedBox(height: 16),

                      // ── Ingredients Section ──────────────────────────────
                      Text(
                        'Komposisi INCI',
                        style: AppTypography.headingSmall
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // ── Ingredient Tab Bar ────────────────────────────────────────
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  child: _IngredientTabBar(
                    controller: _tabController,
                    totalCount: result.ingredients.length,
                    heroCount: heroIngredients.length,
                    warningCount: warningIngredients.length,
                  ),
                ),
              ),

              // ── Ingredient List ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  child: _IngredientTabView(
                    controller: _tabController,
                    result: result,
                    heroIngredients: heroIngredients,
                    warningIngredients: warningIngredients,
                  ),
                ),
              ),
            ],
          ),

          // ── Floating Bottom Actions ────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(AppRoutes.scan),
                      icon: const Icon(LucideIcons.scan_line, size: 16),
                      label: const Text('Pindai Lain'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() => _saved = !_saved),
                      icon: Icon(
                        _saved ? LucideIcons.heart : LucideIcons.heart_off,
                        size: 16,
                      ),
                      label: Text(_saved ? 'Tersimpan' : 'Simpan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _saved
                            ? AppColors.primaryDark
                            : AppColors.primarySage,
                      ),
                    ),
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

// ── SliverAppBar Delegate ─────────────────────────────────────────────────────

class _ProductHeroAppBar extends StatelessWidget {
  const _ProductHeroAppBar({required this.result});
  final ScanAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg) = switch (result.safetyStatus) {
      SafetyStatus.lowRisk => (AppColors.statusSafe, AppColors.statusSafeBg),
      SafetyStatus.moderateRisk =>
        (AppColors.statusWarning, AppColors.statusWarningBg),
      SafetyStatus.highRisk => (AppColors.statusDanger, AppColors.statusDangerBg),
    };

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      leading: IconButton(
        icon: const Icon(LucideIcons.arrow_left, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primaryDark, Color(0xFF2D5440)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        result.brand,
                        style: AppTypography.badgeText.copyWith(
                          color: AppColors.primarySage,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        result.timestamp,
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result.productName,
                    style: AppTypography.headingMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'INCI Terverifikasi',
                          style: AppTypography.badgeText
                              .copyWith(color: statusColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          result.safetyStatus.label.toUpperCase(),
                          style: AppTypography.badgeText
                              .copyWith(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Match Score Card ──────────────────────────────────────────────────────────

class _MatchScoreCard extends StatelessWidget {
  const _MatchScoreCard({required this.result});
  final ScanAnalysisResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          CircularMatchScore(score: result.matchScore),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.safetyStatus.label,
                  style: AppTypography.headingSmall.copyWith(
                    color: _scoreColor(result.matchScore),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  result.routineRecommendation,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.statusSafe;
    if (score >= 60) return AppColors.statusWarning;
    return AppColors.statusDanger;
  }
}

// ── Key Warning Card ──────────────────────────────────────────────────────────

class _KeyWarningCard extends StatelessWidget {
  const _KeyWarningCard({required this.warning});
  final String warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusWarningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.triangle_alert,
              size: 18, color: AppColors.statusWarningDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              warning,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.statusWarningDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ingredient Tab Bar ────────────────────────────────────────────────────────

class _IngredientTabBar extends StatelessWidget {
  const _IngredientTabBar({
    required this.controller,
    required this.totalCount,
    required this.heroCount,
    required this.warningCount,
  });

  final TabController controller;
  final int totalCount;
  final int heroCount;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.backgroundSoft,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundClean,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TabBar(
          controller: controller,
          labelStyle: AppTypography.labelMedium,
          unselectedLabelStyle: AppTypography.labelMedium,
          labelColor: AppColors.primarySage,
          unselectedLabelColor: AppColors.textSecondary,
          indicator: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: AppColors.cardShadow,
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          padding: const EdgeInsets.all(4),
          tabs: [
            Tab(text: 'Semua ($totalCount)'),
            Tab(text: 'Kunci ($heroCount)'),
            Tab(text: 'Perhatian ($warningCount)'),
          ],
        ),
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.child});
  final Widget child;

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// ── Ingredient Tab View ───────────────────────────────────────────────────────

class _IngredientTabView extends StatelessWidget {
  const _IngredientTabView({
    required this.controller,
    required this.result,
    required this.heroIngredients,
    required this.warningIngredients,
  });

  final TabController controller;
  final ScanAnalysisResult result;
  final List<IngredientItem> heroIngredients;
  final List<IngredientItem> warningIngredients;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final ingredients = switch (controller.index) {
          1 => heroIngredients,
          2 => warningIngredients,
          _ => result.ingredients,
        };

        return Column(
          children: ingredients
              .map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: IngredientStatusCard(ingredient: i),
                  ))
              .toList(),
        );
      },
    );
  }
}
