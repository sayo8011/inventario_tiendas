import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_tiendas/core/database/app_database.dart';
import 'package:inventario_tiendas/features/categories/data/category_repository.dart';
import 'package:inventario_tiendas/features/categories/domain/category.dart';
import 'package:inventario_tiendas/features/categories/presentation/categories_provider.dart';
import 'package:inventario_tiendas/features/inventory/data/stock_movement_repository.dart';
import 'package:inventario_tiendas/features/inventory/presentation/inventory_page.dart';
import 'package:inventario_tiendas/features/inventory/presentation/inventory_provider.dart';
import 'package:inventario_tiendas/features/products/data/product_repository.dart';
import 'package:inventario_tiendas/features/products/presentation/products_page.dart';
import 'package:inventario_tiendas/features/products/presentation/products_provider.dart';
import 'package:inventario_tiendas/features/suppliers/data/supplier_repository.dart';
import 'package:inventario_tiendas/features/suppliers/presentation/suppliers_page.dart';
import 'package:inventario_tiendas/features/suppliers/presentation/suppliers_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _NoCategories extends CategoryRepository {
  @override
  Future<List<Category>> getAll() async => const [];
}

/// Recorre las pantallas reales contra una base SQLite real y temporal.
void main() {
  sqfliteFfiInit();

  testWidgets('proveedor, producto, movimientos e historial', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('inventario_flow'),
    ))!;
    final db = (await tester.runAsync(
      () => databaseFactoryFfi.openDatabase(
        p.join(dir.path, 'test.db'),
        options: AppDatabase.openOptions(),
      ),
    ))!;
    final database = Future.value(db);

    // SQLite corre en otro isolate: hay que dejar pasar tiempo real.
    Future<void> settle() async {
      for (var i = 0; i < 15; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    final tab = ValueNotifier<Widget>(const SuppliersPage());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(_NoCategories()),
          supplierRepositoryProvider
              .overrideWithValue(SupplierRepository(database: database)),
          productRepositoryProvider
              .overrideWithValue(ProductRepository(database: database)),
          stockMovementRepositoryProvider
              .overrideWithValue(StockMovementRepository(database: database)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: tab,
              builder: (_, page, _) => page,
            ),
          ),
        ),
      ),
    );
    await settle();

    Finder field(String label) => find.widgetWithText(TextFormField, label);
    Future<void> tapAndSettle(Finder finder) async {
      // Escribir puede cambiar el tamaño del diálogo y mover los botones.
      await tester.pump();
      await tester.tap(finder);
      await settle();
    }

    // Proveedor
    await tapAndSettle(find.text('Nuevo proveedor'));
    await tester.enterText(field('Nombre'), 'Distribuidora Norte');
    await tester.enterText(field('Correo (opcional)'), 'no-es-correo');
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('Escribe un correo válido'), findsOneWidget);
    await tester.enterText(field('Correo (opcional)'), 'ventas@norte.co');
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('Distribuidora Norte'), findsOneWidget);

    // Producto con proveedor y stock inicial
    tab.value = const ProductsPage();
    await settle();
    await tapAndSettle(find.text('Nuevo producto'));
    await tester.enterText(field('Código o código de barras'), 'A1');
    await tester.enterText(field('Nombre'), 'Arroz');
    await tester.enterText(field('Costo (COP)'), '1.000');
    await tester.enterText(field('Precio de venta (COP)'), '1.500,50');
    await tester.enterText(field('Stock inicial'), '10');
    await tapAndSettle(find.text('Sin proveedor'));
    await tapAndSettle(find.text('Distribuidora Norte').last);
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('10 und'), findsOneWidget);
    final saved = (await tester.runAsync(() => db.query('products')))!.single;
    expect(saved['supplier_id'], isNotNull);
    expect(saved['sale_cents'], 150050);

    // Salida rechazada y luego aceptada desde la fila del producto
    await tapAndSettle(find.byTooltip('Registrar movimiento'));
    await tapAndSettle(find.text('Salida'));
    await tester.enterText(field('Cantidad'), '11');
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('Solo hay 10 und disponibles'), findsOneWidget);
    await tester.enterText(field('Cantidad'), '4');
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('6 und'), findsOneWidget);

    // Entrada desde Inventario, buscando el producto
    tab.value = const InventoryPage();
    await settle();
    expect(find.text('−4 und'), findsOneWidget);
    expect(find.text('+10 und'), findsOneWidget);

    await tapAndSettle(find.text('Registrar movimiento'));
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('Elige un producto'), findsOneWidget);

    await tester.enterText(field('Producto'), 'arr');
    await settle();
    await tapAndSettle(find.text('A1 · Arroz').last);
    expect(find.text('Elige un producto'), findsNothing);
    await tester.enterText(field('Cantidad'), '1,5');
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('Esta unidad solo permite números enteros'), findsOneWidget);
    await tester.enterText(field('Cantidad'), '5');
    await settle();
    expect(find.text('Esta unidad solo permite números enteros'), findsNothing);
    expect(find.text('Stock actual: 6 und'), findsOneWidget);
    await tester.enterText(field('Nota (opcional)'), 'Compra');
    await tapAndSettle(find.text('Guardar'));
    expect(find.text('+5 und'), findsOneWidget);
    expect(find.text('Compra'), findsOneWidget);

    // Productos refleja el movimiento hecho en Inventario
    tab.value = const ProductsPage();
    await settle();
    expect(find.text('11 und'), findsOneWidget);

    await tester.runAsync(() async {
      await db.close();
      await dir.delete(recursive: true);
    });
  });
}
