import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../categories/presentation/categories_provider.dart';
import '../../suppliers/presentation/suppliers_provider.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

final productRepositoryProvider =
    Provider<ProductRepository>((ref) => ProductRepository());

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() {
    // Borrar una categoría o un proveedor cambia los productos que los usan.
    ref.watch(categoriesProvider);
    ref.watch(suppliersProvider);
    return ref.read(productRepositoryProvider).getAll();
  }

  Future<void> add(Product product) async {
    await ref.read(productRepositoryProvider).insert(product);
    ref.invalidateSelf();
  }

  Future<void> edit(Product product) async {
    await ref.read(productRepositoryProvider).update(product);
    ref.invalidateSelf();
  }

  Future<void> setActive(int id, bool active) async {
    await ref.read(productRepositoryProvider).setActive(id, active);
    ref.invalidateSelf();
  }
}

final productsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);
