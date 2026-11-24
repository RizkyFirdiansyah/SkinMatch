class ProductCatalogItem {
  const ProductCatalogItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.categorySlug,
    required this.ingredients,
    this.bpomNumber,
    this.price,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String brand;
  final String category;
  final String categorySlug;
  final List<String> ingredients;
  final String? bpomNumber;
  final double? price;
  final String? imageUrl;
}

class ProductCategoryOption {
  const ProductCategoryOption({required this.name, required this.slug});

  final String name;
  final String slug;
}

class ProductCatalogPage {
  const ProductCatalogPage({
    required this.products,
    required this.total,
    required this.offset,
    required this.hasMore,
  });

  final List<ProductCatalogItem> products;
  final int total;
  final int offset;
  final bool hasMore;
}

class ProductSearchFilters {
  const ProductSearchFilters({
    this.categories = const <String>{},
    this.brands = const <String>{},
    this.priceEnabled = false,
    this.minimumPrice,
    this.maximumPrice,
    this.includeIngredients = const <String>[],
    this.excludeIngredients = const <String>[],
  });

  final Set<String> categories;
  final Set<String> brands;
  final bool priceEnabled;
  final double? minimumPrice;
  final double? maximumPrice;
  final List<String> includeIngredients;
  final List<String> excludeIngredients;

  int get activeCount =>
      categories.length +
      brands.length +
      (priceEnabled ? 1 : 0) +
      includeIngredients.length +
      excludeIngredients.length;

  ProductSearchFilters copyWith({
    Set<String>? categories,
    Set<String>? brands,
    bool? priceEnabled,
    double? minimumPrice,
    double? maximumPrice,
    List<String>? includeIngredients,
    List<String>? excludeIngredients,
  }) {
    return ProductSearchFilters(
      categories: categories ?? this.categories,
      brands: brands ?? this.brands,
      priceEnabled: priceEnabled ?? this.priceEnabled,
      minimumPrice: minimumPrice ?? this.minimumPrice,
      maximumPrice: maximumPrice ?? this.maximumPrice,
      includeIngredients: includeIngredients ?? this.includeIngredients,
      excludeIngredients: excludeIngredients ?? this.excludeIngredients,
    );
  }
}
