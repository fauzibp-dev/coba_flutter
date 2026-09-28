import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';
import 'auth_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<Map<String, dynamic>> _future;
  String? _variantId;
  bool _adding = false;
  bool _wishlisted = false;

  @override
  void initState() {
    super.initState();
    _future = ShopRepository.instance.product(widget.productId);
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    if (!ShopRepository.instance.isSignedIn) return;
    final value = await ShopRepository.instance.isWishlisted(widget.productId);
    if (mounted) setState(() => _wishlisted = value);
  }

  Future<bool> _ensureAuth() async {
    if (ShopRepository.instance.isSignedIn) return true;
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    return ok == true || ShopRepository.instance.isSignedIn;
  }

  Future<void> _addToCart(Map<String, dynamic> product, {bool buyNow = false}) async {
    if (!await _ensureAuth()) return;
    final variants = product['product_variants'] as List? ?? [];
    if (variants.isNotEmpty && _variantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih varian produk terlebih dahulu.')));
      return;
    }
    setState(() => _adding = true);
    try {
      await ShopRepository.instance.addToCart(product['id'] as String, variantId: _variantId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk masuk ke keranjang.')));
      if (buyNow) Navigator.pop(context, 'cart');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _toggleWishlist() async {
    if (!await _ensureAuth()) return;
    try {
      final value = await ShopRepository.instance.toggleWishlist(widget.productId);
      if (mounted) setState(() => _wishlisted = value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [
          IconButton(
            onPressed: _toggleWishlist,
            icon: Icon(_wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _wishlisted ? AppTheme.primary : null),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Produk tidak dapat dimuat.'));
          final product = snapshot.data!;
          final images = product['product_images'] as List? ?? [];
          final variants = product['product_variants'] as List? ?? [];
          final reviews = product['reviews'] as List? ?? [];
          final price = (product['price'] ?? 0) as num;
          final compare = product['compare_at_price'] as num?;
          final imageUrl = images.isNotEmpty ? (images.first as Map)['image_url']?.toString() : null;
          final inventory = product['inventory'] as List? ?? [];
          final stock = inventory.fold<int>(0, (sum, e) => sum + (((e as Map)['available_qty'] ?? 0) as num).toInt());
          return Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: imageUrl == null
                          ? Container(color: const Color(0xFFF1F1F1), child: const Icon(Icons.storefront_outlined, size: 74, color: Color(0xFFAAAAAA)))
                          : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.broken_image_outlined, size: 56))),
                    ),
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rupiah(price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                          if (compare != null && compare > price)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(rupiah(compare), style: const TextStyle(color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                            ),
                          const SizedBox(height: 9),
                          Text(product['name']?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5A623)),
                              Text('${((product['rating_average'] ?? 0) as num).toStringAsFixed(1)}  •  ${product['sold_count'] ?? 0} terjual'),
                              const Spacer(),
                              Text('Stok $stock', style: const TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (variants.isNotEmpty)
                      Container(
                        color: Colors.white,
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Pilih Varian', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: variants.map((raw) {
                                final v = Map<String, dynamic>.from(raw as Map);
                                final selected = _variantId == v['id'];
                                return ChoiceChip(
                                  label: Text(v['name']?.toString() ?? '-'),
                                  selected: selected,
                                  onSelected: (_) => setState(() => _variantId = v['id'] as String),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    Container(
                      color: Colors.white,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Deskripsi Produk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 9),
                          Text(
                            (product['description']?.toString().trim().isNotEmpty ?? false) ? product['description'].toString() : 'Belum ada deskripsi produk.',
                            style: const TextStyle(height: 1.55, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      color: Colors.white,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ulasan Pembeli (${reviews.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 10),
                          if (reviews.isEmpty)
                            const Text('Belum ada ulasan.', style: TextStyle(color: AppTheme.textSecondary))
                          else
                            ...reviews.take(3).map((raw) {
                              final review = Map<String, dynamic>.from(raw as Map);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('★' * ((review['rating'] ?? 0) as num).toInt(), style: const TextStyle(color: Color(0xFFF5A623))),
                                    if (review['comment'] != null) Text(review['comment'].toString()),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: stock <= 0 || _adding ? null : () => _addToCart(product),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                          label: const Text('Keranjang'),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: stock <= 0 || _adding ? null : () => _addToCart(product, buyNow: true),
                          child: Text(stock <= 0 ? 'Stok Habis' : (_adding ? 'Memproses...' : 'Beli Sekarang')),
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
    );
  }
}
