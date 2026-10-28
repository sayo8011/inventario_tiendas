import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
  const _NavItem(this.label, this.icon, this.selectedIcon, this.path);
}

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  static const _items = [
    _NavItem('Dashboard', Icons.dashboard_outlined, Icons.dashboard, '/dashboard'),
    _NavItem('Productos', Icons.inventory_2_outlined, Icons.inventory_2, '/products'),
    _NavItem('Categorías', Icons.category_outlined, Icons.category, '/categories'),
    _NavItem('Inventario', Icons.swap_vert_outlined, Icons.swap_vert, '/inventory'),
    _NavItem('Proveedores', Icons.local_shipping_outlined, Icons.local_shipping, '/suppliers'),
    _NavItem('Ventas', Icons.point_of_sale_outlined, Icons.point_of_sale, '/sales'),
    _NavItem('Reportes', Icons.bar_chart_outlined, Icons.bar_chart, '/reports'),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final index = _items.indexWhere((i) => location.startsWith(i.path));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: true,
            minExtendedWidth: 220,
            backgroundColor: Colors.white,
            selectedIndex: _currentIndex(context),
            onDestinationSelected: (i) => context.go(_items[i].path),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront, size: 28),
                  SizedBox(width: 10),
                  Text(
                    'Mi Tienda',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            destinations: [
              for (final item in _items)
                NavigationRailDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: Text(item.label),
                ),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: TextButton.icon(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.logout),
                    label: const Text('Cerrar sesión'),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}