import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/category_repository.dart';
import '../domain/category.dart';

final categoryRepositoryProvider =
    Provider<CategoryRepository>((ref) => CategoryRepository());

class CategoriesNotifier extends AsyncNotifier<List<Category>> {
  @override
  Future<List<Category>> build() {
    return ref.read(categoryRepositoryProvider).getAll();
  }

  Future<void> add(Category category) async {
    await ref.read(categoryRepositoryProvider).insert(category);
    ref.invalidateSelf();
  }

  Future<void> edit(Category category) async {
    await ref.read(categoryRepositoryProvider).update(category);
    ref.invalidateSelf();
  }

  Future<void> remove(int id) async {
    await ref.read(categoryRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final categoriesProvider =
    AsyncNotifierProvider<CategoriesNotifier, List<Category>>(
  CategoriesNotifier.new,
);