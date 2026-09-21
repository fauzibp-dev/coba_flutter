import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/catalog/categories_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/profile/profile_screen.dart';

class ShopShell extends StatefulWidget {
  const ShopShell({super.key});

  @override
  State<ShopShell> createState() => _ShopShellState();
}

class _ShopShellState extends State<ShopShell> {
  int currentIndex = 0;
  int cartCount = 3;

  void addToCart() {
    setState(() => cartCount++);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onAddToCart: addToCart, cartCount: cartCount),
      CategoriesScreen(onAddToCart: addToCart),
      const CartScreen(),
      const OrdersScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppTheme.primary),
            label: 'Beranda',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded, color: AppTheme.primary),
            label: 'Kategori',
          ),
          NavigationDestination(
            icon: _CartIcon(count: cartCount),
            selectedIcon: _CartIcon(count: cartCount, selected: true),
            label: 'Keranjang',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded, color: AppTheme.primary),
            label: 'Pesanan',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.primary),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}

class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.count, this.selected = false});

  final int count;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          selected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined,
          color: selected ? AppTheme.primary : null,
        ),
        if (count > 0)
          Positioned(
            right: -9,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}
