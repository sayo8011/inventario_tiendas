import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../categories/presentation/categories_provider.dart';
import '../../suppliers/presentation/suppliers_provider.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import 'products_provider.dart';

/// Guarda por sí mismo para seguir abierto, sin perder lo escrito, si el
/// guardado falla (por ejemplo, si el código ya existe).
class ProductFormDialog extends ConsumerStatefulWidget {
  final Product? product;
  const ProductFormDialog({super.key, this.product});

  @override
  ConsumerState<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends ConsumerState<ProductFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Product? _product = widget.product;
  late final TextEditingController _code =
      TextEditingController(text: _product?.code);
  late final TextEditingController _name =
      TextEditingController(text: _product?.name);
  late final TextEditingController _cost = TextEditingController(
    text: _product == null ? null : Money.toInput(_product.costCents),
  );
  late final TextEditingController _sale = TextEditingController(
    text: _product == null ? null : Money.toInput(_product.saleCents),
  );
  late final TextEditingController _stock = TextEditingController(text: '0');
  late final TextEditingController _minStock = TextEditingController(
    text: _product == null ? '0' : Quantity.toInput(_product.minStockMilli),
  );

  late int? _categoryId = _product?.categoryId;
  late int? _supplierId = _product?.supplierId;
  late ProductUnit _unit = _product?.unit ?? ProductUnit.unidad;
  String? _codeError;
  String? _saveError;
  bool _saving = false;
  bool _submitted = false;

  bool get _isEdit => _product != null;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _cost.dispose();
    _sale.dispose();
    _stock.dispose();
    _minStock.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  String? _validateMoney(String? value) =>
      Money.parse(value ?? '') == null ? 'Escribe un valor como 1.500,50' : null;

  String? _validateQuantity(String? value) {
    final milli = Quantity.parse(value ?? '');
    if (milli == null) return 'Escribe una cantidad, como 10 o 1,5';
    if (!_unit.allowsDecimals && milli % 1000 != 0) {
      return 'Esta unidad solo permite números enteros';
    }
    return null;
  }

  String? get _belowCostWarning {
    final cost = Money.parse(_cost.text);
    final sale = Money.parse(_sale.text);
    return cost != null && sale != null && sale < cost
        ? 'El precio de venta es menor que el costo'
        : null;
  }

  Future<void> _save() async {
    setState(() {
      _submitted = true;
      _codeError = null;
      _saveError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final product = Product(
      id: _product?.id,
      code: _code.text.trim(),
      name: _name.text.trim(),
      categoryId: _categoryId,
      supplierId: _supplierId,
      costCents: Money.parse(_cost.text)!,
      saleCents: Money.parse(_sale.text)!,
      stockMilli: _product?.stockMilli ?? Quantity.parse(_stock.text)!,
      minStockMilli: Quantity.parse(_minStock.text)!,
      unit: _unit,
    );

    setState(() => _saving = true);
    final notifier = ref.read(productsProvider.notifier);
    try {
      if (_isEdit) {
        await notifier.edit(product);
      } else {
        await notifier.add(product);
      }
      if (mounted) Navigator.pop(context);
    } on DuplicateProductCodeException {
      if (mounted) setState(() => _codeError = 'Ya existe un producto con ese código');
    } catch (e) {
      if (mounted) setState(() => _saveError = 'No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value;
    final suppliers = ref.watch(suppliersProvider).value;
    final warning = _belowCostWarning;
    const gap = SizedBox(height: 16);
    const columnGap = SizedBox(width: 16);

    return AlertDialog(
      title: Text(_isEdit ? 'Editar producto' : 'Nuevo producto'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  controller: _code,
                  autofocus: !_isEdit,
                  forceErrorText: _codeError,
                  decoration: const InputDecoration(
                    labelText: 'Código o código de barras',
                  ),
                  validator: (v) =>
                      _validateRequired(v, 'El código es obligatorio'),
                  onChanged: (_) {
                    if (_codeError != null) setState(() => _codeError = null);
                  },
                ),
                gap,
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      _validateRequired(v, 'El nombre es obligatorio'),
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: categories == null
                          ? const LinearProgressIndicator()
                          : DropdownButtonFormField<int?>(
                              initialValue:
                                  categories.any((c) => c.id == _categoryId)
                                      ? _categoryId
                                      : null,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Categoría',
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Sin categoría'),
                                ),
                                for (final c in categories)
                                  DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: (v) => _categoryId = v,
                            ),
                    ),
                    columnGap,
                    Expanded(
                      child: DropdownButtonFormField<ProductUnit>(
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Unidad de medida',
                          helperText:
                              _isEdit ? 'No se puede cambiar después' : null,
                        ),
                        items: [
                          for (final u in ProductUnit.values)
                            DropdownMenuItem(value: u, child: Text(u.label)),
                        ],
                        onChanged: _isEdit
                            ? null
                            : (v) => setState(() => _unit = v!),
                      ),
                    ),
                  ],
                ),
                gap,
                if (suppliers == null)
                  const LinearProgressIndicator()
                else
                  DropdownButtonFormField<int?>(
                    initialValue: suppliers.any((s) => s.id == _supplierId)
                        ? _supplierId
                        : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Proveedor'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Sin proveedor'),
                      ),
                      for (final s in suppliers)
                        DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => _supplierId = v,
                  ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        decoration: const InputDecoration(
                          labelText: 'Costo (COP)',
                          prefixText: r'$ ',
                        ),
                        validator: _validateMoney,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    columnGap,
                    Expanded(
                      child: TextFormField(
                        controller: _sale,
                        decoration: InputDecoration(
                          labelText: 'Precio de venta (COP)',
                          prefixText: r'$ ',
                          helperText: warning,
                          helperMaxLines: 2,
                          helperStyle: warning == null
                              ? null
                              : TextStyle(color: Colors.orange.shade900),
                        ),
                        validator: _validateMoney,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                gap,
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _isEdit
                          ? InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Stock actual',
                                helperText: 'Se cambia con un movimiento',
                              ),
                              child: Text(
                                '${Quantity.format(_product!.stockMilli)} '
                                '${_unit.symbol}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            )
                          : TextFormField(
                              controller: _stock,
                              decoration: InputDecoration(
                                labelText: 'Stock inicial',
                                suffixText: _unit.symbol,
                              ),
                              validator: _validateQuantity,
                            ),
                    ),
                    columnGap,
                    Expanded(
                      child: TextFormField(
                        controller: _minStock,
                        decoration: InputDecoration(
                          labelText: 'Stock mínimo',
                          suffixText: _unit.symbol,
                        ),
                        validator: _validateQuantity,
                      ),
                    ),
                  ],
                ),
                if (_saveError != null) ...[
                  gap,
                  Text(
                    _saveError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
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
