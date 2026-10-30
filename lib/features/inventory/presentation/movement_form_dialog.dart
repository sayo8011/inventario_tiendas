import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/products_provider.dart';
import '../data/stock_movement_repository.dart';
import '../domain/stock_movement.dart';
import 'inventory_provider.dart';

/// Registra una entrada, salida o ajuste. Con [product] el producto queda
/// fijo; sin él, se busca entre los productos activos.
class MovementFormDialog extends ConsumerStatefulWidget {
  final Product? product;
  const MovementFormDialog({super.key, this.product});

  @override
  ConsumerState<MovementFormDialog> createState() => _MovementFormDialogState();
}

class _MovementFormDialogState extends ConsumerState<MovementFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _note = TextEditingController();

  late Product? _selected = widget.product;
  MovementType _type = MovementType.entry;
  String? _quantityError;
  String? _saveError;
  bool _saving = false;
  bool _submitted = false;

  bool get _isAdjustment => _type == MovementType.adjustment;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  String _withUnit(int milli, Product product) =>
      '${Quantity.format(milli)} ${product.unit.symbol}';

  String? _validateQuantity(String? value) {
    final milli = Quantity.parse(value ?? '');
    if (milli == null) return 'Escribe una cantidad, como 10 o 1,5';
    if (!_isAdjustment && milli == 0) return 'La cantidad debe ser mayor que 0';
    final unit = _selected?.unit;
    if (unit != null && !unit.allowsDecimals && milli % 1000 != 0) {
      return 'Esta unidad solo permite números enteros';
    }
    return null;
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _quantityError = null;
      _saveError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final product = _selected!;
    final note = _note.text.trim();

    setState(() => _saving = true);
    try {
      await ref.read(stockMovementsProvider.notifier).register(
            productId: product.id!,
            type: _type,
            quantityMilli: Quantity.parse(_quantity.text)!,
            note: note.isEmpty ? null : note,
          );
      if (mounted) Navigator.pop(context);
    } on InsufficientStockException catch (e) {
      if (mounted) {
        setState(() => _quantityError =
            'Solo hay ${_withUnit(e.availableMilli, product)} disponibles');
      }
    } on NoStockChangeException {
      if (mounted) {
        setState(() => _quantityError = 'Es igual al stock actual');
      }
    } catch (e) {
      if (mounted) setState(() => _saveError = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildProductField() {
    final fixed = widget.product;
    if (fixed != null) {
      return InputDecorator(
        decoration: const InputDecoration(labelText: 'Producto'),
        child: Text(
          '${fixed.code} · ${fixed.name}',
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final products = ref.watch(productsProvider).value ?? const <Product>[];
    return Autocomplete<Product>(
      displayStringForOption: (p) => '${p.code} · ${p.name}',
      optionsBuilder: (value) => products
          .where((p) => p.active && p.matchesSearch(value.text))
          .take(20),
      onSelected: (p) => setState(() => _selected = p),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
          TextFormField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Producto',
          hintText: 'Busca por nombre o código',
        ),
        validator: (_) => _selected == null ? 'Elige un producto' : null,
        onChanged: (_) {
          if (_selected != null) setState(() => _selected = null);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    const gap = SizedBox(height: 16);

    return AlertDialog(
      title: const Text('Registrar movimiento'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              _buildProductField(),
              gap,
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<MovementType>(
                  showSelectedIcon: false,
                  segments: [
                    for (final t in const [
                      MovementType.entry,
                      MovementType.exit,
                      MovementType.adjustment,
                    ])
                      ButtonSegment(value: t, label: Text(t.label)),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() {
                    _type = s.single;
                    _quantityError = null;
                  }),
                ),
              ),
              gap,
              TextFormField(
                controller: _quantity,
                autofocus: widget.product != null,
                forceErrorText: _quantityError,
                decoration: InputDecoration(
                  labelText:
                      _isAdjustment ? 'Cantidad contada' : 'Cantidad',
                  suffixText: selected?.unit.symbol,
                  helperText: selected == null
                      ? null
                      : 'Stock actual: '
                          '${_withUnit(selected.stockMilli, selected)}',
                ),
                validator: _validateQuantity,
                onChanged: (_) {
                  if (_quantityError != null) {
                    setState(() => _quantityError = null);
                  }
                },
              ),
              gap,
              TextFormField(
                controller: _note,
                decoration: const InputDecoration(
                  labelText: 'Nota (opcional)',
                ),
              ),
              if (_saveError != null) ...[
                gap,
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
