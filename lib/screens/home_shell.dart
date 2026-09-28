import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/shop_repository.dart';
import 'account_screen.dart';
import 'auth_screen.dart';
import 'cart_screen.dart';
import 'home_screen.dart';
import 'orders_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  Future<bool> _ensureAuth() async {
    if (ShopRepository.instance.isSignedIn) return true;
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
    if (mounted) setState(() {});
    return ok == true || ShopRepository.instance.isSignedIn;
  }

  Future<void> _select(int value) async {
    if ((value == 2 || value == 3) && !await _ensureAuth()) return;
    if (mounted) setState(() => _index = value);
  }

  Widget _page() {
    switch (_index) {
      case 1:
        return const SearchScreen(embedded: true);
      case 2:
        return const CartScreen(embedded: true);
      case 3:
        return const OrdersScreen(embedded: true);
      case 4:
        return AccountScreen(onAuthChanged: () => setState(() {}));
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _page(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        indicatorColor: const Color(0xFFFFE5E5),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.search_rounded), selectedIcon: Icon(Icons.search_rounded, color: AppTheme.primary), label: 'Cari'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart_rounded, color: AppTheme.primary), label: 'Keranjang'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded, color: AppTheme.primary), label: 'Pesanan'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary), label: 'Akun'),
        ],
      ),
    );
  }
}
