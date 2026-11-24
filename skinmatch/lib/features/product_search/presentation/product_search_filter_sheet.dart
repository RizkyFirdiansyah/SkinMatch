import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../shared/models/product_catalog_models.dart';

class ProductSearchFilterSheet extends StatefulWidget {
  const ProductSearchFilterSheet({
    super.key,
    required this.categories,
    required this.brands,
    required this.initialFilters,
  });

  final List<ProductCategoryOption> categories;
  final List<String> brands;
  final ProductSearchFilters initialFilters;

  @override
  State<ProductSearchFilterSheet> createState() =>
      _ProductSearchFilterSheetState();
}

class _ProductSearchFilterSheetState extends State<ProductSearchFilterSheet> {
  static const double _maximumPrice = 200000;

  late Set<String> _selectedCategories;
  late Set<String> _selectedBrands;
  late bool _priceEnabled;
  late RangeValues _priceRange;
  late List<String> _includeIngredients;
  late List<String> _excludeIngredients;
  final _includeController = TextEditingController();
  final _excludeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final filters = widget.initialFilters;
    _selectedCategories = Set.of(filters.categories);
    _selectedBrands = Set.of(filters.brands);
    _priceEnabled = filters.priceEnabled;
    final minimum = (filters.minimumPrice ?? 0)
        .clamp(0, _maximumPrice)
        .toDouble();
    final maximum = (filters.maximumPrice ?? _maximumPrice)
        .clamp(minimum, _maximumPrice)
        .toDouble();
    _priceRange = RangeValues(minimum, maximum);
    _includeIngredients = List.of(filters.includeIngredients);
    _excludeIngredients = List.of(filters.excludeIngredients);
  }

  @override
  void dispose() {
    _includeController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: SafeArea(
          top: false,
          child: Material(
            color: AppColors.backgroundSoft,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Filter',
                          style: AppTypography.headingMedium.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _reset,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategorySection(),
                        const SizedBox(height: 24),
                        _buildBrandSection(),
                        const SizedBox(height: 24),
                        _buildPriceSection(),
                        const SizedBox(height: 24),
                        _buildIngredientSection(
                          title: 'Mengandung bahan',
                          hint: 'Tambah bahan yang dicari',
                          values: _includeIngredients,
                          controller: _includeController,
                          onAdd: _addIncludedIngredient,
                          onRemove: (value) => setState(
                            () => _includeIngredients.remove(value),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildIngredientSection(
                          title: 'Tanpa bahan',
                          hint: 'Tambah bahan yang dihindari',
                          values: _excludeIngredients,
                          controller: _excludeController,
                          onAdd: _addExcludedIngredient,
                          onRemove: (value) => setState(
                            () => _excludeIngredients.remove(value),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_filters),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: const Text('Tampilkan produk'),
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

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(title: 'Kategori', trailing: 'Pilih lebih dari satu'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.categories.map((category) {
            final selected = _selectedCategories.contains(category.slug);
            return _ChoiceChip(
              label: category.name,
              selected: selected,
              onSelected: () => setState(() {
                if (selected) {
                  _selectedCategories.remove(category.slug);
                } else {
                  _selectedCategories.add(category.slug);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBrandSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(title: 'Merek'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.brands.map((brand) {
            final selected = _selectedBrands.contains(brand);
            return _ChoiceChip(
              label: brand,
              selected: selected,
              onSelected: () => setState(() {
                if (selected) {
                  _selectedBrands.remove(brand);
                } else {
                  _selectedBrands.add(brand);
                }
              }),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPriceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeading(
          title: 'Rentang harga',
          trailing: _priceEnabled
              ? '${_formatRupiah(_priceRange.start)}–${_formatRupiah(_priceRange.end)}'
              : 'Semua harga',
        ),
        RangeSlider(
          values: _priceRange,
          min: 0,
          max: _maximumPrice,
          divisions: 20,
          labels: RangeLabels(
            _formatRupiah(_priceRange.start),
            _formatRupiah(_priceRange.end),
          ),
          activeColor: AppColors.primarySage,
          inactiveColor: AppColors.borderLight,
          onChanged: (range) => setState(() {
            _priceEnabled = true;
            _priceRange = range;
          }),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _pricePreset('Di bawah Rp50rb', 0, 50000),
            _pricePreset('Rp50–100rb', 50000, 100000),
            _pricePreset('Rp100–150rb', 100000, 150000),
            _pricePreset('Di atas Rp150rb', 150000, _maximumPrice),
          ],
        ),
      ],
    );
  }

  Widget _pricePreset(String label, double minimum, double maximum) {
    final selected =
        _priceEnabled &&
        _priceRange.start == minimum &&
        _priceRange.end == maximum;
    return _ChoiceChip(
      label: label,
      selected: selected,
      onSelected: () => setState(() {
        _priceEnabled = true;
        _priceRange = RangeValues(minimum, maximum);
      }),
    );
  }

  Widget _buildIngredientSection({
    required String title,
    required String hint,
    required List<String> values,
    required TextEditingController controller,
    required VoidCallback onAdd,
    required ValueChanged<String> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(
                  hintText: hint,
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.cardSurface,
                  suffixIcon: IconButton(
                    tooltip: 'Tambah bahan',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (values.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (value) => InputChip(
                    label: Text(value),
                    onDeleted: () => onRemove(value),
                    deleteIconColor: AppColors.statusDanger,
                    backgroundColor: AppColors.statusSafeBg,
                    labelStyle: AppTypography.labelSmall.copyWith(
                      color: AppColors.primaryDark,
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  void _addIncludedIngredient() {
    _addIngredient(_includeController, _includeIngredients);
  }

  void _addExcludedIngredient() {
    _addIngredient(_excludeController, _excludeIngredients);
  }

  void _addIngredient(
    TextEditingController controller,
    List<String> values,
  ) {
    final value = controller.text.trim();
    if (value.isEmpty ||
        values.any((existing) => existing.toLowerCase() == value.toLowerCase())) {
      return;
    }
    setState(() {
      values.add(value);
      controller.clear();
    });
  }

  ProductSearchFilters get _filters => ProductSearchFilters(
    categories: Set.unmodifiable(_selectedCategories),
    brands: Set.unmodifiable(_selectedBrands),
    priceEnabled: _priceEnabled,
    minimumPrice: _priceEnabled ? _priceRange.start : null,
    maximumPrice: _priceEnabled ? _priceRange.end : null,
    includeIngredients: List.unmodifiable(_includeIngredients),
    excludeIngredients: List.unmodifiable(_excludeIngredients),
  );

  void _reset() {
    setState(() {
      _selectedCategories.clear();
      _selectedBrands.clear();
      _priceEnabled = false;
      _priceRange = const RangeValues(0, _maximumPrice);
      _includeIngredients.clear();
      _excludeIngredients.clear();
      _includeController.clear();
      _excludeController.clear();
    });
  }

  String _formatRupiah(double value) {
    final formatted = value.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return 'Rp$formatted';
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: AppColors.cardSurface,
      selectedColor: AppColors.statusSafeBg,
      side: BorderSide(
        color: selected ? AppColors.primarySage : AppColors.borderLight,
      ),
      labelStyle: AppTypography.labelSmall.copyWith(
        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
