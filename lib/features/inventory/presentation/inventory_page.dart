import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/formatters.dart';
import '../data/stock_movement_repository.dart';
import '../domain/stock_movement.dart';
import 'inventory_provider.dart';
import 'movement_form_dialog.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> {
  String _query = '';
  MovementType? _type;

  void _openForm() {
    showDialog<void>(
      context: context,
      builder: (_) => const MovementFormDialog(),
    );
  }

  bool _matches(StockMovement m) {
    if (_type != null && m.type != _type) return false;
    final q = _query.trim().toLowerCase();
    return m.productName.toLowerCase().contains(q) ||
        m.productCode.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final movements = ref.watch(stockMovementsProvider);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Inventario',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: _openForm,
                icon: const Icon(Icons.swap_vert),
                label: const Text('Registrar movimiento'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Buscar por producto o código',
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
                    child: DropdownButton<MovementType?>(
                      value: _type,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Todos los tipos'),
                        ),
                        for (final t in MovementType.values)
                          DropdownMenuItem(value: t, child: Text(t.label)),
                      ],
                      onChanged: (v) => setState(() => _type = v),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: movements.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                if (all.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay movimientos de stock.'),
                  );
                }
                final list = all.where(_matches).toList();
                final truncated =
                    all.length == StockMovementRepository.recentLimit;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: list.isEmpty
                          ? const Center(
                              child: Text(
                                'Ningún movimiento coincide con los filtros.',
                              ),
                            )
                          : Card(
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  const _HeaderRow(),
                                  const Divider(height: 1),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: list.length,
                                      separatorBuilder: (_, _) =>
                                          const Divider(height: 1),
                                      itemBuilder: (context, i) =>
                                          _MovementRow(list[i]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    if (truncated)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Se muestran los '
                          '${StockMovementRepository.recentLimit} '
                          'movimientos más recientes.',
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Columns extends StatelessWidget {
  final Widget date;
  final Widget product;
  final Widget type;
  final Widget quantity;
  final Widget note;

  const _Columns({
    required this.date,
    required this.product,
    required this.type,
    required this.quantity,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(width: 130, child: date),
          Expanded(flex: 4, child: product),
          SizedBox(width: 120, child: type),
          SizedBox(width: 120, child: quantity),
          Expanded(flex: 3, child: note),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    Widget label(String text) => Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        );

    return _Columns(
      date: label('Fecha'),
      product: label('Producto'),
      type: label('Tipo'),
      quantity: label('Cantidad'),
      note: label('Nota'),
    );
  }
}

class _MovementRow extends StatelessWidget {
  static final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  final StockMovement movement;
  const _MovementRow(this.movement);

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final isPositive = m.quantityMilli > 0;
    Widget cell(String text) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: text,
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        );

    return _Columns(
      date: cell(_dateFormat.format(m.createdAt)),
      product: cell('${m.productCode} · ${m.productName}'),
      type: cell(m.type.label),
      quantity: Text(
        '${isPositive ? '+' : '−'}'
        '${Quantity.format(m.quantityMilli.abs())} ${m.unit.symbol}',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isPositive ? Colors.green.shade800 : Colors.red.shade800,
        ),
      ),
      note: cell(m.note ?? '—'),
    );
  }
}
