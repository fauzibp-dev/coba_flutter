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
  // Lock cart mutations until Supabase confirms and the newest cart is read.
  // Without this lock, rapid +/-/delete taps can race against stale quantities.
  String? _pendingItemId;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = ShopRepository.instance.cartItems();

  Future<void> _change(Map<String, dynamic> item, int delta) async {
    final current = ((item['quantity'] ?? 1) as num).toInt();
    final next = current + delta;
    // A "-" at quantity one must not silently remove the product.
    if (next < 1 || next > 99) return;
    await _mutateItem(item, next);
  }

  Future<void> _remove(Map<String, dynamic> item) => _mutateItem(item, 0);

  Future<void> _mutateItem(Map<String, dynamic> item, int desiredQuantity) async {
    // Only one cart mutation may be in flight at a time. The backend RPC
    // takes an absolute quantity, so overlapping stale requests can undo
    // changes or try to mutate an item that was already deleted.
    if (_pendingItemId != null) return;
    final itemId = item['id'] as String;
    setState(() => _pendingItemId = itemId);

    try {
      await ShopRepository.instance.setCartQuantity(itemId, desiredQuantity);
      // A 204 RPC response alone is not enough to show the mutation as PASS.
      // Read the authoritative quantity back from Supabase.
      final freshItems = await ShopRepository.instance.cartItems();
      final matching = freshItems.where((element) => element['id'] == itemId);
      final savedQuantity = matching.isEmpty
          ? null
          : ((matching.first['quantity'] ?? 0) as num).toInt();
      if ((desiredQuantity == 0 && savedQuantity != null) ||
          (desiredQuantity > 0 && savedQuantity != desiredQuantity)) {
        throw StateError('CART_NOT_SYNCED');
      }
      if (!mounted) return;
      setState(() => _future = Future.value(freshItems));
    } catch (error) {
      if (!mounted) return;
      // Never swallow PostgREST errors: show a useful message, then refresh
      // to remove stale rows (e.g. after "Cart item not found").
      final message = friendlyError(error);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: SnackBarAction(
              label: 'Muat ulang',
              onPressed: () {
                if (mounted) setState(_reload);
              },
            ),
          ),
        );
      setState(_reload);
    } finally {
      if (mounted) setState(() => _pendingItemId = null);
    }
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
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Gagal memuat keranjang.'),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => setState(_reload),
                          child: const Text('Coba lagi'),
                        ),
                      ],
                    ),
                  );
                }
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
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final product = Map<String, dynamic>.from(item['products'] as Map);
                          final variant = item['product_variants'];
                          final images = product['product_images'] as List? ?? [];
                          final imageUrl = images.isNotEmpty ? (images.first as Map)['image_url']?.toString() : null;
                          final qty = ((item['quantity'] ?? 1) as num).toInt();
                          final busy = _pendingItemId != null;
                          final updatingThisItem = _pendingItemId == item['id'];
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
                                        : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.broken_image_outlined))),
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
                                          _QtyButton(
                                            icon: Icons.remove,
                                            semanticLabel: 'Kurangi jumlah ${product['name'] ?? 'produk'}',
                                            enabled: !busy && qty > 1,
                                            onTap: () => _change(item, -1),
                                          ),
                                          SizedBox(
                                            width: 38,
                                            child: Semantics(
                                              container: true,
                                              label: 'Jumlah ${product['name'] ?? 'produk'}: $qty',
                                              child: ExcludeSemantics(
                                                child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                                              ),
                                            ),
                                          ),
                                          _QtyButton(
                                            icon: Icons.add,
                                            semanticLabel: 'Tambah jumlah ${product['name'] ?? 'produk'}',
                                            enabled: !busy && qty < 99,
                                            onTap: () => _change(item, 1),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            tooltip: 'Hapus ${product['name'] ?? 'produk'} dari keranjang',
                                            onPressed: busy ? null : () => _remove(item),
                                            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                      if (updatingThisItem)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 8),
                                          child: LinearProgressIndicator(minHeight: 2),
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
                                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(rupiah(subtotal), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.primary))),
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
  const _QtyButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    required this.enabled,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? onTap : null,
      child: InkWell(
        excludeFromSemantics: true,
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 18, color: enabled ? null : AppTheme.textSecondary.withValues(alpha: 0.4)),
        ),
      ),
    );
  }
}
