import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/presentation/products_provider.dart';
import '../data/stock_movement_repository.dart';
import '../domain/stock_movement.dart';

final stockMovementRepositoryProvider = Provider<StockMovementRepository>(
  (ref) => StockMovementRepository(),
);

class StockMovementsNotifier extends AsyncNotifier<List<StockMovement>> {
  @override
  Future<List<StockMovement>> build() {
    // También se recarga con los productos: su alta genera un movimiento
    // inicial y su edición puede cambiar el nombre mostrado en el historial.
    ref.watch(productsProvider);
    return ref.read(stockMovementRepositoryProvider).getRecent();
  }

  Future<void> register({
    required int productId,
    required MovementType type,
    required int quantityMilli,
    String? note,
  }) async {
    await ref.read(stockMovementRepositoryProvider).register(
          productId: productId,
          type: type,
          quantityMilli: quantityMilli,
          note: note,
        );
    ref.invalidate(productsProvider);
  }
}

final stockMovementsProvider =
    AsyncNotifierProvider<StockMovementsNotifier, List<StockMovement>>(
  StockMovementsNotifier.new,
);
