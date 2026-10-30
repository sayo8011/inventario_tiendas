import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/supplier_repository.dart';
import '../domain/supplier.dart';

final supplierRepositoryProvider =
    Provider<SupplierRepository>((ref) => SupplierRepository());

class SuppliersNotifier extends AsyncNotifier<List<Supplier>> {
  @override
  Future<List<Supplier>> build() {
    return ref.read(supplierRepositoryProvider).getAll();
  }

  Future<void> add(Supplier supplier) async {
    await ref.read(supplierRepositoryProvider).insert(supplier);
    ref.invalidateSelf();
  }

  Future<void> edit(Supplier supplier) async {
    await ref.read(supplierRepositoryProvider).update(supplier);
    ref.invalidateSelf();
  }

  Future<void> remove(int id) async {
    await ref.read(supplierRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}

final suppliersProvider =
    AsyncNotifierProvider<SuppliersNotifier, List<Supplier>>(
  SuppliersNotifier.new,
);
