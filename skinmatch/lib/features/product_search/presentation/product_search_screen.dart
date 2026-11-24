import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/product_catalog_models.dart';
import 'product_search_filter_sheet.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() =>
      _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  static const int _pageSize = 30;
  static const _searchModes = [
    ('all', 'Semua'),
    ('name', 'Nama'),
    ('brand', 'Merek'),
    ('ingredient', 'Bahan'),
  ];
  static const _sortOptions = {
    'name': 'Nama A–Z',
    'price_asc': 'Harga terendah',
    'price_desc': 'Harga tertinggi',
  };

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  List<ProductCatalogItem> _products = [];
  List<ProductCategoryOption> _categories = [];
  List<String> _brands = [];
  ProductSearchFilters _filters = const ProductSearchFilters();
  String _searchIn = 'all';
  String _sortBy = 'name';
  String? _error;
  String? _filterOptionsError;
  bool _filtersLoading = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _total = 0;
  int _offset = 0;
  int _searchGeneration = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadNextPage);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadFilterOptions();
      _fetchProducts();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_loadNextPage)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadFilterOptions() async {
    if (!mounted) return;
    setState(() {
      _filtersLoading = true;
      _filterOptionsError = null;
    });
    final api = ref.read(apiClientProvider);
    try {
      final categories = await api.getProductCategories();
      if (!mounted) return;
      setState(() => _categories = categories);
      final brands = await api.getProductBrands();
      if (!mounted) return;
      setState(() {
        _brands = brands;
        _filterOptionsError = null;
        _filtersLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _filterOptionsError = error.message;
        _filtersLoading = false;
      });
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _fetchProducts(),
    );
    setState(() {});
  }

  Future<void> _fetchProducts({bool append = false}) async {
    if (append && (_loading || _loadingMore || !_hasMore)) return;
    if (!append && _scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    final generation = ++_searchGeneration;
    setState(() {
      if (append) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
        _hasMore = false;
        _offset = 0;
        _products = [];
        _total = 0;
        _error = null;
      }
    });

    try {
      final page = await ref
          .read(apiClientProvider)
          .searchCatalogProducts(
            keyword: _searchController.text,
            searchIn: _searchIn,
            filters: _filters,
            sortBy: _sortBy,
            limit: _pageSize,
            offset: append ? _offset : 0,
          );
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _products = append ? [..._products, ...page.products] : page.products;
        _total = page.total;
        _offset = page.offset + page.products.length;
        _hasMore = page.hasMore;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiException catch (error) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = error.message;
      });
    }
  }

  void _loadNextPage() {
    if (!_scrollController.hasClients ||
        _scrollController.position.extentAfter > 240) {
      return;
    }
    unawaited(_fetchProducts(append: true));
  }

  void _setSearchMode(String mode) {
    if (_searchIn == mode) return;
    setState(() => _searchIn = mode);
    _fetchProducts();
  }

  Future<void> _openFilters() async {
    if (_filtersLoading) return;
    final updatedFilters = await showModalBottomSheet<ProductSearchFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductSearchFilterSheet(
        categories: _categories,
        brands: _brands,
        initialFilters: _filters,
      ),
    );
    if (!mounted || updatedFilters == null) return;
    setState(() => _filters = updatedFilters);
    _fetchProducts();
  }

  void _updateFilters(ProductSearchFilters filters) {
    setState(() => _filters = filters);
    _fetchProducts();
  }

  List<Widget> _buildActiveFilterChips() {
    final chips = <Widget>[];
    for (final slug in _filters.categories) {
      final category = _categories.where((item) => item.slug == slug);
      final label = category.isEmpty ? slug : category.first.name;
      chips.add(
        _ActiveFilterChip(
          label: label,
          onDeleted: () {
            final categories = Set<String>.of(_filters.categories)
              ..remove(slug);
            _updateFilters(_filters.copyWith(categories: categories));
          },
        ),
      );
    }
    for (final brand in _filters.brands) {
      chips.add(
        _ActiveFilterChip(
          label: brand,
          onDeleted: () {
            final brands = Set<String>.of(_filters.brands)..remove(brand);
            _updateFilters(_filters.copyWith(brands: brands));
          },
        ),
      );
    }
    if (_filters.priceEnabled) {
      chips.add(
        _ActiveFilterChip(
          label:
              '${_formatRupiah(_filters.minimumPrice ?? 0)}–${_formatRupiah(_filters.maximumPrice ?? 200000)}',
          onDeleted: () =>
              _updateFilters(_filters.copyWith(priceEnabled: false)),
        ),
      );
    }
    for (final ingredient in _filters.includeIngredients) {
      chips.add(
        _ActiveFilterChip(
          label: 'Mengandung $ingredient',
          onDeleted: () {
            final ingredients = List<String>.of(_filters.includeIngredients)
              ..remove(ingredient);
            _updateFilters(_filters.copyWith(includeIngredients: ingredients));
          },
        ),
      );
    }
    for (final ingredient in _filters.excludeIngredients) {
      chips.add(
        _ActiveFilterChip(
          label: 'Tanpa $ingredient',
          onDeleted: () {
            final ingredients = List<String>.of(_filters.excludeIngredients)
              ..remove(ingredient);
            _updateFilters(_filters.copyWith(excludeIngredients: ingredients));
          },
        ),
      );
    }
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final activeFilterChips = _buildActiveFilterChips();
    return Scaffold(
      backgroundColor: AppColors.backgroundSoft,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Kembali',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => _scheduleSearch(),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          _searchDebounce?.cancel();
                          _fetchProducts();
                        },
                        decoration: InputDecoration(
                          hintText: 'Cari produk',
                          isDense: true,
                          prefixIcon: const Icon(Icons.search, size: 20),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Hapus pencarian',
                                  onPressed: () {
                                    _searchController.clear();
                                    _fetchProducts();
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        tooltip: _filtersLoading
                            ? 'Memuat filter'
                            : 'Buka filter',
                        onPressed: _openFilters,
                        icon: _filtersLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.tune),
                      ),
                      if (_filters.activeCount > 0)
                        Positioned(
                          right: 2,
                          top: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.statusDanger,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${_filters.activeCount}',
                              style: AppTypography.labelSmall.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _searchModes
                    .map(
                      (mode) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(mode.$2),
                          selected: _searchIn == mode.$1,
                          onSelected: (_) => _setSearchMode(mode.$1),
                          selectedColor: AppColors.primaryDark,
                          backgroundColor: AppColors.cardSurface,
                          side: BorderSide(
                            color: _searchIn == mode.$1
                                ? AppColors.primaryDark
                                : AppColors.borderLight,
                          ),
                          labelStyle: AppTypography.labelSmall.copyWith(
                            color: _searchIn == mode.$1
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          showCheckmark: false,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (activeFilterChips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: activeFilterChips,
                ),
              ),
            if (_filterOptionsError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _filterOptionsError!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.statusDanger,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadFilterOptions,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$_total produk ditemukan',
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DropdownButton<String>(
                    value: _sortBy,
                    underline: const SizedBox.shrink(),
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    items: _sortOptions.entries
                        .map(
                          (option) => DropdownMenuItem(
                            value: option.key,
                            child: Text(option.value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _sortBy = value);
                      _fetchProducts();
                    },
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _products.isEmpty) {
      return _SearchMessage(
        message: _error!,
        actionLabel: 'Coba Lagi',
        onAction: _fetchProducts,
      );
    }
    if (_products.isEmpty) {
      return const Center(
        child: Text(
          'Produk tidak ditemukan. Coba ubah kata kunci atau filter.',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _products.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: _loadingMore
                  ? const CircularProgressIndicator()
                  : TextButton(
                      onPressed: () => _fetchProducts(append: true),
                      child: const Text('Muat produk lainnya'),
                    ),
            ),
          );
        }
        return _ProductResultCard(product: _products[index]);
      },
    );
  }

  String _formatRupiah(double value) {
    final formatted = value.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return 'Rp$formatted';
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIconColor: AppColors.primaryDark,
      backgroundColor: AppColors.statusSafeBg,
      labelStyle: AppTypography.labelSmall.copyWith(
        color: AppColors.primaryDark,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _ProductResultCard extends StatelessWidget {
  const _ProductResultCard({required this.product});

  final ProductCatalogItem product;

  @override
  Widget build(BuildContext context) {
    final visibleIngredients = product.ingredients.take(2).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySageLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  product.brand.isEmpty ? '?' : product.brand[0].toUpperCase(),
                  style: AppTypography.headingMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.brand.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${product.category} · ${_formatPrice(product.price)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (visibleIngredients.isNotEmpty ||
              (product.bpomNumber?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderMuted),
            const SizedBox(height: 8),
            Row(
              children: [
                if (visibleIngredients.isNotEmpty)
                  Expanded(
                    child: Text(
                      'Bahan: ${visibleIngredients.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primarySage,
                      ),
                    ),
                  ),
                if (product.bpomNumber?.isNotEmpty ?? false)
                  Text(
                    'BPOM ${product.bpomNumber}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatPrice(double? price) {
    if (price == null) return 'Harga tidak tersedia';
    final formatted = price.toInt().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
    return 'Rp$formatted';
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
