import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/routing/app_router.dart';
import '../../../shared/models/skinmatch_models.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../widgets/skin_type_card.dart';

/// /profile — Onboarding & Formulir Tipe Kulit
/// Sesuai PRD Section 2B: Profile header, demografi, skin type radio cards
class SkinProfileScreen extends ConsumerStatefulWidget {
  const SkinProfileScreen({super.key});

  @override
  ConsumerState<SkinProfileScreen> createState() => _SkinProfileScreenState();
}

class _SkinProfileScreenState extends ConsumerState<SkinProfileScreen> {
  final _nameController = TextEditingController();
  AgeRange _selectedAge = AgeRange.range25to34;
  BiologicalSex _selectedSex = BiologicalSex.female;
  BiologicalSkinType? _selectedSkinType;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _onSave() async {
    if (_selectedSkinType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tipe kulit terlebih dahulu')),
      );
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isLoading = false);
    context.go(AppRoutes.scan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      appBar: SkinMatchAppBar(
        title: 'Profil Kulit',
        leading: IconButton(
          icon: const Icon(LucideIcons.arrow_left),
          onPressed: () => context.go(AppRoutes.auth),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar & User ID ───────────────────────────────────────
                _ProfileHeader(),
                const SizedBox(height: 28),

                // ── Demografi Klinis ───────────────────────────────────────
                _SectionTitle(title: 'Demografi Klinis'),
                const SizedBox(height: 12),

                // Nama Lengkap
                TextField(
                  controller: _nameController,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nama Lengkap',
                    prefixIcon: const Icon(LucideIcons.user,
                        size: 18, color: AppColors.textSecondary),
                    hintStyle: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 12),

                // Rentang Usia
                _PillSelector<AgeRange>(
                  label: 'Rentang Usia',
                  items: AgeRange.values,
                  selected: _selectedAge,
                  labelOf: (a) => a.label,
                  onSelect: (a) => setState(() => _selectedAge = a),
                ),
                const SizedBox(height: 12),

                // Profil Hormonal
                _PillSelector<BiologicalSex>(
                  label: 'Profil Hormonal',
                  items: BiologicalSex.values,
                  selected: _selectedSex,
                  labelOf: (s) => s.label,
                  onSelect: (s) => setState(() => _selectedSex = s),
                ),
                const SizedBox(height: 28),

                // ── Tipe Kulit ─────────────────────────────────────────────
                _SectionTitle(title: 'Tipe Kulit Biologis'),
                const SizedBox(height: 4),
                Text(
                  'Pilih satu tipe yang paling menggambarkan kondisi kulit Anda',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),

                ...BiologicalSkinType.values.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SkinTypeCard(
                      skinType: type,
                      isSelected: _selectedSkinType == type,
                      onTap: () => setState(() => _selectedSkinType = type),
                    ),
                  );
                }),
              ],
            ),
          ),

          // ── Floating CTA ───────────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: AppColors.backgroundSoft,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: PrimaryButton(
                label: 'Simpan & Terapkan',
                onPressed: _onSave,
                isLoading: _isLoading,
                icon: LucideIcons.sparkles,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.statusSafeBg,
              child: const Icon(
                LucideIcons.user,
                size: 36,
                color: AppColors.primarySage,
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primarySage,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.backgroundSoft, width: 2),
                ),
                child: const Icon(
                  LucideIcons.camera,
                  size: 12,
                  color: AppColors.textOnDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pengguna Baru',
              style: AppTypography.headingSmall
                  .copyWith(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.backgroundClean,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Text(
                '#SKIN-88219',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.headingSmall.copyWith(color: AppColors.textPrimary),
    );
  }
}

class _PillSelector<T> extends StatelessWidget {
  const _PillSelector({
    required this.label,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final String label;
  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final void Function(T) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              AppTypography.labelMedium.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: items.map((item) {
            final isSelected = item == selected;
            return GestureDetector(
              onTap: () => onSelect(item),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarySage
                      : AppColors.backgroundClean,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primarySage
                        : AppColors.borderLight,
                  ),
                ),
                child: Text(
                  labelOf(item),
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected
                        ? AppColors.textOnDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
