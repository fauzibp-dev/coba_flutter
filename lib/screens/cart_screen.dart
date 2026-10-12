import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = ShopRepository.instance.cartItems();

  Future<void> _change(Map<String, dynamic> item, int delta) async {
    final current = ((item['quantity'] ?? 1) as num).toInt();
    await ShopRepository.instance.setCartQuantity(item['id'] as String, current + delta);
    if (mounted) setState(_reload);
  }

  num _itemPrice(Map<String, dynamic> item) {
    final product = Map<String, dynamic>.from(item['products'] as Map);
    final variant = item['product_variants'];
    if (variant is Map && variant['price_override'] != null) return variant['price_override'] as num;
    return (product['price'] ?? 0) as num;
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (widget.embedded)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: const Text('Keranjang', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return const Center(child: Text('Gagal memuat keranjang.'));
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 54, color: AppTheme.textSecondary),
                          SizedBox(height: 12),
                          Text('Keranjang masih kosong', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          SizedBox(height: 5),
                          Text('Tambahkan produk dari katalog KKMP Kerten.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                final subtotal = items.fold<num>(0, (sum, item) => sum + _itemPrice(item) * ((item['quantity'] ?? 1) as num));
                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final product = Map<String, dynamic>.from(item['products'] as Map);
                          final variant = item['product_variants'];
                          final images = product['product_images'] as List? ?? [];
                          final imageUrl = images.isNotEmpty ? (images.first as Map)['image_url']?.toString() : null;
                          final qty = ((item['quantity'] ?? 1) as num).toInt();
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: SizedBox(
                                    width: 76,
                                    height: 76,
                                    child: imageUrl == null
                                        ? Container(color: const Color(0xFFF1F1F1), child: const Icon(Icons.inventory_2_outlined, color: AppTheme.textSecondary))
                                        : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.broken_image_outlined))),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(product['name']?.toString() ?? '-', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      if (variant is Map) Padding(padding: const EdgeInsets.only(top: 3), child: Text(variant['name']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                                      const SizedBox(height: 8),
                                      Text(rupiah(_itemPrice(item)), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800)),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _QtyButton(icon: Icons.remove, onTap: () => _change(item, -1)),
                                          SizedBox(width: 38, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                                          _QtyButton(icon: Icons.add, onTap: () => _change(item, 1)),
                                          const Spacer(),
                                          IconButton(
                                            onPressed: () async {
                                              await ShopRepository.instance.removeCartItem(item['id'] as String);
                                              if (mounted) setState(_reload);
                                            },
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        color: Colors.white,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Subtotal', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  Text(rupiah(subtotal), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 150,
                              child: FilledButton(
                                onPressed: () async {
                                  final completed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                                  if (completed == true && mounted) setState(_reload);
                                },
                                child: const Text('Checkout'),
                              ),
                            ),
                          ],
                        ),
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
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Keranjang')), body: body);
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 17),
      ),
    );
  }
}
