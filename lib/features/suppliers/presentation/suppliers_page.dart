import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/supplier.dart';
import 'suppliers_provider.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Supplier? supplier,
  }) async {
    final result = await showDialog<Supplier>(
      context: context,
      builder: (_) => SupplierDialog(supplier: supplier),
    );
    if (result == null) return;

    final notifier = ref.read(suppliersProvider.notifier);
    try {
      if (result.id == null) {
        await notifier.add(result);
      } else {
        await notifier.edit(result);
      }
    } on DatabaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Supplier supplier,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar proveedor'),
        content: Text(
          '¿Eliminar "${supplier.name}"? Sus productos quedarán sin proveedor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await ref.read(suppliersProvider.notifier).remove(supplier.id!);
    } on DatabaseException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliers = ref.watch(suppliersProvider);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Proveedores',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openForm(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Nuevo proveedor'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: suppliers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(
                    child: Text('Aún no hay proveedores. Crea el primero.'),
                  );
                }
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final contact = [s.phone, s.email, s.address]
                          .whereType<String>()
                          .join(' · ');
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.local_shipping_outlined),
                        ),
                        title: Text(s.name),
                        subtitle: contact.isEmpty ? null : Text(contact),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () =>
                                  _openForm(context, ref, supplier: s),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  _confirmDelete(context, ref, s),
                            ),
                          ],
                        ),
                      );
                    },
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

class SupplierDialog extends StatefulWidget {
  final Supplier? supplier;
  const SupplierDialog({super.key, this.supplier});

  @override
  State<SupplierDialog> createState() => _SupplierDialogState();
}

class _SupplierDialogState extends State<SupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name =
      TextEditingController(text: widget.supplier?.name);
  late final TextEditingController _phone =
      TextEditingController(text: widget.supplier?.phone);
  late final TextEditingController _email =
      TextEditingController(text: widget.supplier?.email);
  late final TextEditingController _address =
      TextEditingController(text: widget.supplier?.address);
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  void _save() {
    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Supplier(
        id: widget.supplier?.id,
        name: _name.text.trim(),
        phone: _optional(_phone),
        email: _optional(_email),
        address: _optional(_address),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;
    return AlertDialog(
      title: Text(isEdit ? 'Editar proveedor' : 'Nuevo proveedor'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          autovalidateMode: _submitted
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'El nombre es obligatorio'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(
                    labelText: 'Correo (opcional)',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                    return text.isEmpty || valid.hasMatch(text)
                        ? null
                        : 'Escribe un correo válido';
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(
                    labelText: 'Dirección (opcional)',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}
