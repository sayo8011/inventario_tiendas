import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventario_tiendas/features/categories/data/category_repository.dart';
import 'package:inventario_tiendas/features/categories/domain/category.dart';
import 'package:inventario_tiendas/features/categories/presentation/categories_provider.dart';
import 'package:inventario_tiendas/features/products/data/product_repository.dart';
import 'package:inventario_tiendas/features/products/domain/product.dart';
import 'package:inventario_tiendas/features/products/presentation/product_form_dialog.dart';
import 'package:inventario_tiendas/features/products/presentation/products_provider.dart';
import 'package:inventario_tiendas/features/suppliers/data/supplier_repository.dart';
import 'package:inventario_tiendas/features/suppliers/domain/supplier.dart';
import 'package:inventario_tiendas/features/suppliers/presentation/suppliers_provider.dart';

class _FakeCategories extends CategoryRepository {
  @override
  Future<List<Category>> getAll() async => const [];
}

class _FakeSuppliers extends SupplierRepository {
  @override
  Future<List<Supplier>> getAll() async =>
      const [Supplier(id: 3, name: 'Distribuidora Norte')];
}

class _FakeProducts extends ProductRepository {
  final List<Product> inserted = [];
  final List<Product> updated = [];
  bool failWithDuplicate = false;

  @override
  Future<List<Product>> getAll() async => const [];

  @override
  Future<int> insert(Product product) async {
    if (failWithDuplicate) throw const DuplicateProductCodeException();
    inserted.add(product);
    return 1;
  }

  @override
  Future<int> update(Product product) async {
    updated.add(product);
    return 1;
  }
}

void main() {
  late _FakeProducts products;

  setUp(() => products = _FakeProducts());

  Future<void> pumpForm(WidgetTester tester, {Product? product}) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(_FakeCategories()),
          supplierRepositoryProvider.overrideWithValue(_FakeSuppliers()),
          productRepositoryProvider.overrideWithValue(products),
        ],
        child: MaterialApp(
          home: Scaffold(body: ProductFormDialog(product: product)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextFormField, label);

  Future<void> fillValid(WidgetTester tester) async {
    await tester.enterText(field('Código o código de barras'), ' A1 ');
    await tester.enterText(field('Nombre'), ' Arroz ');
    await tester.enterText(field('Costo (COP)'), '1.000,50');
    await tester.enterText(field('Precio de venta (COP)'), '1.500');
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
  }

  testWidgets('no guarda si faltan datos obligatorios', (tester) async {
    await pumpForm(tester);
    await save(tester);

    expect(find.text('El código es obligatorio'), findsOneWidget);
    expect(find.text('El nombre es obligatorio'), findsOneWidget);
    expect(find.text('Escribe un valor como 1.500,50'), findsNWidgets(2));
    expect(products.inserted, isEmpty);
  });

  testWidgets('guarda con los valores convertidos', (tester) async {
    await pumpForm(tester);
    await fillValid(tester);
    await tester.enterText(field('Stock inicial'), '12');
    await save(tester);

    final saved = products.inserted.single;
    expect(saved.code, 'A1');
    expect(saved.name, 'Arroz');
    expect(saved.costCents, 100050);
    expect(saved.saleCents, 150000);
    expect(saved.stockMilli, 12000);
  });

  testWidgets('guarda el proveedor elegido', (tester) async {
    await pumpForm(tester);
    await fillValid(tester);
    await tester.tap(find.text('Sin proveedor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distribuidora Norte').last);
    await tester.pumpAndSettle();
    await save(tester);

    expect(products.inserted.single.supplierId, 3);
  });

  testWidgets('la unidad por defecto no admite decimales', (tester) async {
    await pumpForm(tester);
    await fillValid(tester);
    await tester.enterText(field('Stock inicial'), '1,5');
    await save(tester);

    expect(find.text('Esta unidad solo permite números enteros'), findsOneWidget);
    expect(products.inserted, isEmpty);
  });

  testWidgets('avisa sin bloquear si se vende por debajo del costo', (tester) async {
    await pumpForm(tester);
    await fillValid(tester);
    await tester.enterText(field('Precio de venta (COP)'), '900');
    await tester.pump();

    expect(find.text('El precio de venta es menor que el costo'), findsOneWidget);

    await save(tester);
    expect(products.inserted.single.saleCents, 90000);
  });

  testWidgets('un código repetido se muestra en el campo y conserva lo escrito',
      (tester) async {
    products.failWithDuplicate = true;
    await pumpForm(tester);
    await fillValid(tester);
    await save(tester);

    expect(find.text('Ya existe un producto con ese código'), findsOneWidget);
    expect(find.text('Arroz', skipOffstage: false), findsNothing,
        reason: 'el campo conserva el texto original, con espacios');
    expect(find.text(' Arroz '), findsOneWidget);
  });

  testWidgets('al editar precarga los datos y no permite cambiar stock',
      (tester) async {
    await pumpForm(
      tester,
      product: const Product(
        id: 5,
        code: 'A1',
        name: 'Arroz',
        costCents: 123450,
        saleCents: 150000,
        stockMilli: 1250000,
        minStockMilli: 500,
        unit: ProductUnit.kg,
      ),
    );

    expect(find.text('1234,50'), findsOneWidget);
    expect(find.text('1500'), findsOneWidget);
    expect(find.text('0,5'), findsOneWidget);
    expect(find.text('1.250 kg'), findsOneWidget);
    expect(field('Stock inicial'), findsNothing);

    await save(tester);
    final saved = products.updated.single;
    expect(saved.id, 5);
    expect(saved.costCents, 123450);
    expect(saved.minStockMilli, 500);
  });
}
