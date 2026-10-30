import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../categories/presentation/categories_provider.dart';
import '../../inventory/presentation/movement_form_dialog.dart';
import '../domain/product.dart';
import 'product_form_dialog.dart';
import 'products_provider.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  /// Por debajo de este ancho la tabla se desplaza de lado, para no cortar los
  /// precios.
  static const double _minTableWidth = 960;

  final _horizontalScroll = ScrollController();
  String _query = '';
  int? _categoryId;
  bool _showInactive = false;

  @override
  void dispose() {
    _horizontalScroll.dispose();
    super.dispose();
  }

  void _openForm({Product? product}) {
    showDialog<void>(
      context: context,
      builder: (_) => ProductFormDialog(product: product),
    );
  }

  void _openMovement(Product product) {
    showDialog<void>(
      context: context,
      builder: (_) => MovementFormDialog(product: product),
    );
  }

  Future<void> _setActive(Product product, bool active) async {
    try {
      await ref.read(productsProvider.notifier).setActive(product.id!, active);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo actualizar el producto: $e')),
      );
    }
  }

  Future<void> _confirmDeactivate(Product product) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar producto'),
        content: Text(
          '¿Desactivar "${product.name}"? Dejará de aparecer en la lista, pero '
          'su historial se conserva y podrás reactivarlo cuando quieras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (ok == true) await _setActive(product, false);
  }

  List<Product> _filter(List<Product> products) => products
      .where((p) => _showInactive || p.active)
      .where((p) => _categoryId == null || p.categoryId == _categoryId)
      .where((p) => p.matchesSearch(_query))
      .toList();

  @override
  Widget build(BuildContext context) {
    final products = ref.watch(productsProvider);
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final selectedCategory =
        categories.any((c) => c.id == _categoryId) ? _categoryId : null;
    if (selectedCategory != _categoryId) _categoryId = selectedCategory;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Productos',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo producto'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por nombre o código',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 220,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: selectedCategory,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todas las categorías'),
                        ),
                        for (final c in categories)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: const Text('Mostrar inactivos'),
                selected: _showInactive,
                onSelected: (v) => setState(() => _showInactive = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: products.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                if (all.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay productos. Crea el primero.'),
                  );
                }
                final list = _filter(all);
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Ningún producto coincide con los filtros.'),
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) => Scrollbar(
                      controller: _horizontalScroll,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _horizontalScroll,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: max(constraints.maxWidth, _minTableWidth),
                          height: constraints.maxHeight,
                          child: Column(
                            children: [
                              const _TableHeader(),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: list.length,
                                  separatorBuilder: (_, _) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, i) {
                                    final p = list[i];
                                    return _ProductRow(
                                      product: p,
                                      onMove: () => _openMovement(p),
                                      onEdit: () => _openForm(product: p),
                                      onDeactivate: () => _confirmDeactivate(p),
                                      onReactivate: () => _setActive(p, true),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de la tabla, compartida por el encabezado y los productos para que
/// las columnas queden alineadas.
class _Columns extends StatelessWidget {
  final Widget code;
  final Widget name;
  final Widget category;
  final Widget cost;
  final Widget sale;
  final Widget stock;
  final Widget actions;

  const _Columns({
    required this.code,
    required this.name,
    required this.category,
    required this.cost,
    required this.sale,
    required this.stock,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(flex: 2, child: code),
          Expanded(flex: 4, child: name),
          Expanded(flex: 2, child: category),
          Expanded(flex: 3, child: cost),
          Expanded(flex: 3, child: sale),
          Expanded(flex: 3, child: stock),
          SizedBox(width: 144, child: actions),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    Widget label(String text) => Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );

    return _Columns(
      code: label('Código'),
      name: label('Nombre'),
      category: label('Categoría'),
      cost: label('Costo'),
      sale: label('Venta'),
      stock: label('Stock'),
      actions: const SizedBox.shrink(),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final VoidCallback onMove;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  const _ProductRow({
    required this.product,
    required this.onMove,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final p = product;
    Widget cell(String text) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: text,
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        );

    return Opacity(
      opacity: p.active ? 1 : 0.5,
      child: _Columns(
        code: cell(p.code),
        name: cell(p.name),
        category: cell(p.categoryName ?? '—'),
        cost: cell(Money.format(p.costCents)),
        sale: cell(Money.format(p.saleCents)),
        stock: Row(
          children: [
            Flexible(
              child: cell('${Quantity.format(p.stockMilli)} ${p.unit.symbol}'),
            ),
            if (!p.active)
              const _StatusTag('Inactivo', Colors.blueGrey)
            else if (p.isOutOfStock)
              const _StatusTag('Agotado', Colors.red)
            else if (p.isLowStock)
              const _StatusTag('Bajo', Colors.orange),
          ],
        ),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (p.active)
              IconButton(
                tooltip: 'Registrar movimiento',
                icon: const Icon(Icons.swap_vert),
                onPressed: onMove,
              ),
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            if (p.active)
              IconButton(
                tooltip: 'Desactivar',
                icon: const Icon(Icons.visibility_off_outlined),
                onPressed: onDeactivate,
              )
            else
              IconButton(
                tooltip: 'Reactivar',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: onReactivate,
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  final String label;
  final MaterialColor color;
  const _StatusTag(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: color.shade900),
      ),
    );
  }
}
