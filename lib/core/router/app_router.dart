import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/categories/presentation/categories_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';
import '../../features/inventory/presentation/inventory_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/reports/presentation/reports_page.dart';
import '../../features/sales/presentation/sales_page.dart';
import '../../features/suppliers/presentation/suppliers_page.dart';
import '../widgets/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/dashboard',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (c, s) => const DashboardPage()),
        GoRoute(path: '/products', builder: (c, s) => const ProductsPage()),
        GoRoute(path: '/categories', builder: (c, s) => const CategoriesPage()),
        GoRoute(path: '/inventory', builder: (c, s) => const InventoryPage()),
        GoRoute(path: '/suppliers', builder: (c, s) => const SuppliersPage()),
        GoRoute(path: '/sales', builder: (c, s) => const SalesPage()),
        GoRoute(path: '/reports', builder: (c, s) => const ReportsPage()),
      ],
    ),
  ],
);