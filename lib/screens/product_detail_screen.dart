import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/commerce_repository.dart';
import '../services/shop_repository.dart';
import '../services/variant_repository.dart';
import 'auth_screen.dart';
import 'cart_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late Future<List<dynamic>> _future;
  String? _variantId;
  bool _adding = false;
  bool _wishlisted = false;

  @override
  void initState() {
    super.initState();
    _reload();
    _loadWishlist();
    CommerceRepository.instance.recordProductView(widget.productId);
  }

  void _reload() {
    _future = Future.wait([
      ShopRepository.instance.product(widget.productId),
      VariantRepository.instance.load(widget.productId),
      CommerceRepository.instance.flashSaleProducts(),
    ]);
  }

  Future<void> _loadWishlist() async {
    if (!ShopRepository.instance.isSignedIn) return;
    final value = await ShopRepository.instance.isWishlisted(widget.productId);
    if (mounted) setState(() => _wishlisted = value);
  }

  Future<bool> _ensureAuth() async {
    if (ShopRepository.instance.isSignedIn) return true;
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (!mounted) return false;
    return ok == true || ShopRepository.instance.isSignedIn;
  }

  int _stock(List inventory, List variants) {
    if (variants.isNotEmpty && _variantId != null) {
      return inventory.where((raw) => (raw as Map)['variant_id'] == _variantId).fold<int>(0, (sum, raw) => sum + (((raw as Map)['available_qty'] ?? 0) as num).toInt());
    }
    if (variants.isNotEmpty) return 0;
    return inventory.where((raw) => (raw as Map)['variant_id'] == null).fold<int>(0, (sum, raw) => sum + (((raw as Map)['available_qty'] ?? 0) as num).toInt());
  }

  num _baseDisplayPrice(Map<String, dynamic> product, List variants) {
    if (_variantId != null) {
      for (final raw in variants) {
        final v = raw as Map;
        if (v['id'] == _variantId && v['price_override'] != null) return v['price_override'] as num;
      }
    }
    return (product['price'] ?? 0) as num;
  }

  String? _imageUrl(List images, List variants) {
    if (_variantId != null) {
      final selected = variants.where((raw) => (raw as Map)['id'] == _variantId).toList();
      if (selected.isNotEmpty && (selected.first as Map)['image_url'] != null) return (selected.first as Map)['image_url'].toString();
    }
    if (images.isEmpty) return null;
    final rows = images.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final primary = rows.where((e) => e['is_primary'] == true).toList();
    return (primary.isNotEmpty ? primary.first : rows.first)['image_url']?.toString();
  }

  Map<String, List<String>> _variantLabels(List<Map<String, dynamic>> options, List<Map<String, dynamic>> links) {
    final optionNames = {for (final option in options) option['id'].toString(): option['name']?.toString() ?? 'Opsi'};
    final valueNames = <String, String>{};
    final valueOption = <String, String>{};
    for (final option in options) {
      for (final raw in (option['product_option_values'] as List? ?? [])) {
        final value = Map<String, dynamic>.from(raw as Map);
        valueNames[value['id'].toString()] = value['value']?.toString() ?? '-';
        valueOption[value['id'].toString()] = option['id'].toString();
      }
    }
    final out = <String, List<String>>{};
    for (final link in links) {
      final variantId = link['variant_id'].toString();
      final valueId = link['option_value_id'].toString();
      final optionId = valueOption[valueId];
      if (optionId != null) out.putIfAbsent(variantId, () => []).add('${optionNames[optionId]}: ${valueNames[valueId]}');
    }
    return out;
  }

  Future<void> _addToCart(Map<String, dynamic> product, {bool buyNow = false}) async {
    if (!await _ensureAuth()) return;
    final variants = (product['product_variants'] as List? ?? []).where((raw) => (raw as Map)['is_active'] == true).toList();
    if (variants.isNotEmpty && _variantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih varian produk terlebih dahulu.')));
      return;
    }
    setState(() => _adding = true);
    try {
      await ShopRepository.instance.addToCart(product['id'] as String, variantId: _variantId);
      if (!mounted) return;
      if (buyNow) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk masuk ke keranjang.')));
      }
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Detail Produk'),
          actions: [IconButton(onPressed: _toggleWishlist, icon: Icon(_wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _wishlisted ? AppTheme.primary : null))],
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return Center(child: Text('Produk tidak dapat dimuat: ${snapshot.hasError ? friendlyError(snapshot.error!) : ''}'));
            final product = snapshot.data![0] as Map<String, dynamic>;
            final variantData = snapshot.data![1] as Map<String, dynamic>;
            final flashRows = snapshot.data![2] as List<Map<String, dynamic>>;
            final images = product['product_images'] as List? ?? [];
            final variants = (product['product_variants'] as List? ?? []).where((raw) => (raw as Map)['is_active'] == true).toList();
            final reviews = product['reviews'] as List? ?? [];
            final inventory = product['inventory'] as List? ?? [];
            final options = variantData['options'] as List<Map<String, dynamic>>;
            final links = variantData['links'] as List<Map<String, dynamic>>;
            final labels = _variantLabels(options, links);
            final basePrice = _baseDisplayPrice(product, variants);
            final flash = flashRows.where((e) => e['id'] == product['id']).toList();
            final flashPrice = flash.isNotEmpty && flash.first['campaign_price'] != null ? flash.first['campaign_price'] as num : null;
            final price = flashPrice != null && flashPrice < basePrice ? flashPrice : basePrice;
            final compare = flashPrice != null && flashPrice < basePrice ? basePrice : product['compare_at_price'] as num?;
            final imageUrl = _imageUrl(images, variants);
            final stock = _stock(inventory, variants);
            final requiresVariant = variants.isNotEmpty && _variantId == null;

            return Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async { setState(_reload); await _future; },
                    child: ListView(
                      children: [
                        AspectRatio(
                          aspectRatio: 1,
                          child: imageUrl == null
                              ? Container(color: const Color(0xFFF1F1F1), child: const Icon(Icons.storefront_outlined, size: 74, color: Color(0xFFAAAAAA)))
                              : Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.broken_image_outlined, size: 56))),
                        ),
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (flashPrice != null && flashPrice < basePrice)
                              Container(margin: const EdgeInsets.only(bottom: 7), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFFECEC), borderRadius: BorderRadius.circular(6)), child: Text(flash.first['campaign_name']?.toString() ?? 'Flash Sale', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primary))),
                            Text(rupiah(price), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                            if (compare != null && compare > price) Padding(padding: const EdgeInsets.only(top: 2), child: Text(rupiah(compare), style: const TextStyle(color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough))),
                            const SizedBox(height: 9),
                            Text(product['name']?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3)),
                            const SizedBox(height: 10),
                            Row(children: [
                              const Icon(Icons.star_rounded, size: 18, color: Color(0xFFF5A623)),
                              Text('${((product['rating_average'] ?? 0) as num).toStringAsFixed(1)} (${product['rating_count'] ?? reviews.length}) • ${product['sold_count'] ?? 0} terjual'),
                              const Spacer(),
                              Text(requiresVariant ? 'Pilih varian' : 'Stok $stock', style: const TextStyle(color: AppTheme.textSecondary)),
                            ]),
                          ]),
                        ),
                        if (variants.isNotEmpty)
                          Container(
                            color: Colors.white,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(16),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Text('Pilih Varian', style: TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: variants.map((raw) {
                                  final v = Map<String, dynamic>.from(raw as Map);
                                  final selected = _variantId == v['id'];
                                  final variantStock = inventory.where((entry) => (entry as Map)['variant_id'] == v['id']).fold<int>(0, (sum, entry) => sum + ((((entry as Map)['available_qty']) ?? 0) as num).toInt());
                                  final detail = labels[v['id'].toString()]?.join(' • ');
                                  return ChoiceChip(
                                    label: Text('${v['name'] ?? '-'}${detail == null ? '' : ' • $detail'}${variantStock <= 0 ? ' • Habis' : ''}'),
                                    selected: selected,
                                    onSelected: variantStock <= 0 ? null : (_) => setState(() => _variantId = v['id'] as String),
                                  );
                                }).toList(),
                              ),
                            ]),
                          ),
                        Container(
                          color: Colors.white,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Deskripsi Produk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 9),
                            Text((product['description']?.toString().trim().isNotEmpty ?? false) ? product['description'].toString() : 'Belum ada deskripsi produk.', style: const TextStyle(height: 1.55, color: AppTheme.textSecondary)),
                          ]),
                        ),
                        Container(
                          color: Colors.white,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Ulasan Pembeli (${reviews.length})', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 10),
                            if (reviews.isEmpty)
                              const Text('Belum ada ulasan.', style: TextStyle(color: AppTheme.textSecondary))
                            else
                              ...reviews.take(8).map((raw) {
                                final review = Map<String, dynamic>.from(raw as Map);
                                final reviewImages = review['review_images'] as List? ?? [];
                                final helpful = review['review_helpful_votes'] as List? ?? [];
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.only(bottom: 12),
                                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.border))),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('★' * ((review['rating'] ?? 0) as num).toInt(), style: const TextStyle(color: Color(0xFFF5A623))),
                                    if (review['comment'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(review['comment'].toString())),
                                    if (reviewImages.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(height: 74, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: reviewImages.length, separatorBuilder: (_, _) => const SizedBox(width: 6), itemBuilder: (_, i) {
                                        final img = reviewImages[i] as Map;
                                        return ClipRRect(borderRadius: BorderRadius.circular(7), child: Image.network(img['image_url'].toString(), width: 74, height: 74, fit: BoxFit.cover));
                                      })),
                                    ],
                                    if (review['seller_reply'] != null) ...[
                                      const SizedBox(height: 8),
                                      Container(width: double.infinity, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(8)), child: Text('Balasan toko: ${review['seller_reply']}', style: const TextStyle(fontSize: 12))),
                                    ],
                                    const SizedBox(height: 5),
                                    InkWell(
                                      onTap: () async {
                                        if (!await _ensureAuth()) return;
                                        await ShopRepository.instance.toggleHelpfulReview(review['id'] as String);
                                        if (mounted) setState(_reload);
                                      },
                                      child: Text('Membantu (${helpful.length})', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w700)),
                                    ),
                                  ]),
                                );
                              }),
                          ]),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Row(children: [
                      Expanded(child: OutlinedButton.icon(onPressed: stock <= 0 || _adding || requiresVariant ? null : () => _addToCart(product), icon: const Icon(Icons.add_shopping_cart_rounded), label: const Text('Keranjang'), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)))),
                      const SizedBox(width: 10),
                      Expanded(child: FilledButton(onPressed: stock <= 0 || _adding || requiresVariant ? null : () => _addToCart(product, buyNow: true), child: Text(stock <= 0 && !requiresVariant ? 'Stok Habis' : (requiresVariant ? 'Pilih Varian' : (_adding ? 'Memproses...' : 'Beli Sekarang'))))),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      );
}
