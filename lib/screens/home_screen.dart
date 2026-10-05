import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/commerce_repository.dart';
import '../services/shop_repository.dart';
import '../widgets/product_card.dart';
import 'auth_screen.dart';
import 'notifications_screen.dart';
import 'product_detail_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _data = Future.wait([
      ShopRepository.instance.banners(),
      ShopRepository.instance.categories(),
      ShopRepository.instance.products(),
      CommerceRepository.instance.flashSaleProducts(),
      CommerceRepository.instance.bestSellers(),
      CommerceRepository.instance.newestProducts(),
      CommerceRepository.instance.recentlyViewed(),
    ]);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _data;
  }

  Future<void> _notifications() async {
    if (!ShopRepository.instance.isSignedIn) {
      await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!mounted || !ShopRepository.instance.isSignedIn) return;
    }
    if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _openProduct(Map<String, dynamic> product) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: product['id'] as String)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            FutureBuilder<List<dynamic>>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: _StateMessage(
                      title: 'Gagal memuat Shop Mart',
                      subtitle: 'Periksa koneksi internet lalu coba lagi.',
                      onTap: () => setState(_reload),
                    ),
                  );
                }
                final banners = snapshot.data![0] as List<Map<String, dynamic>>;
                final categories = snapshot.data![1] as List<Map<String, dynamic>>;
                final products = snapshot.data![2] as List<Map<String, dynamic>>;
                final flash = snapshot.data![3] as List<Map<String, dynamic>>;
                final best = snapshot.data![4] as List<Map<String, dynamic>>;
                final newest = snapshot.data![5] as List<Map<String, dynamic>>;
                final recent = snapshot.data![6] as List<Map<String, dynamic>>;
                return SliverList(
                  delegate: SliverChildListDelegate([
                    if (banners.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _PromoBanner(data: banners.first),
                      ),
                    _categories(categories),
                    if (flash.isNotEmpty) _marketSection('Flash Sale', 'Harga promo terbatas', flash, flash: true),
                    if (best.isNotEmpty) _marketSection('Terlaris', 'Paling banyak dibeli', best),
                    if (recent.isNotEmpty) _marketSection('Baru Dilihat', 'Lanjutkan yang sempat kamu lihat', recent),
                    if (newest.isNotEmpty) _marketSection('Produk Terbaru', 'Baru masuk katalog', newest),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Text('Semua Produk', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ),
                    if (products.isEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 10, 16, 44),
                        child: _EmptyCatalog(),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.59,
                        ),
                        itemCount: products.length,
                        itemBuilder: (_, i) => ProductCard(product: products[i], onTap: () => _openProduct(products[i])),
                      ),
                  ]),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Shop Mart', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      SizedBox(height: 2),
                      Text('Belanja koperasi dengan lebih mudah', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Notifikasi', onPressed: _notifications, icon: const Icon(Icons.notifications_none_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, size: 21, color: AppTheme.textSecondary),
                    SizedBox(width: 9),
                    Text('Cari produk, promo, atau kategori...', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _categories(List<Map<String, dynamic>> categories) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: Row(
              children: [
                const Expanded(child: Text('Kategori', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                Text('${categories.length} kategori', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            height: 84,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final category = categories[index];
                return InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(
                        initialCategoryId: category['id'] as String,
                        initialCategoryName: category['name'] as String,
                      ),
                    ),
                  ),
                  child: SizedBox(
                    width: 68,
                    child: Column(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(color: Color(0xFFFFECEC), shape: BoxShape.circle),
                          child: Icon(_categoryIcon(category['icon_name']?.toString()), color: AppTheme.primary),
                        ),
                        const SizedBox(height: 5),
                        Text(category['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      );

  Widget _marketSection(String title, String subtitle, List<Map<String, dynamic>> products, {bool flash = false}) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                        Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (flash) const Icon(Icons.bolt_rounded, color: AppTheme.primary),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 205,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (_, i) => _MiniProduct(product: products[i], flash: flash, onTap: () => _openProduct(products[i])),
              ),
            ),
          ],
        ),
      );

  IconData _categoryIcon(String? name) {
    switch (name) {
      case 'local_drink':
        return Icons.local_drink_outlined;
      case 'cookie':
        return Icons.cookie_outlined;
      case 'home':
        return Icons.home_outlined;
      case 'storefront':
        return Icons.storefront_outlined;
      default:
        return Icons.rice_bowl_outlined;
    }
  }
}

class _MiniProduct extends StatelessWidget {
  const _MiniProduct({required this.product, required this.onTap, this.flash = false});
  final Map<String, dynamic> product;
  final VoidCallback onTap;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    final images = (product['product_images'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final primary = images.where((e) => e['is_primary'] == true).toList();
    final image = (primary.isNotEmpty ? primary.first : (images.isNotEmpty ? images.first : null))?['image_url']?.toString();
    final price = flash && product['campaign_price'] != null ? product['campaign_price'] as num : (product['price'] ?? 0) as num;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 142,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppTheme.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: image == null ? const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.inventory_2_outlined)) : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF1F1F1), child: Icon(Icons.broken_image_outlined))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product['name']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(rupiah(price), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w900)),
                  if (flash && product['campaign_price'] != null && (product['price'] as num?) != null && (product['price'] as num) > price)
                    Text(rupiah(product['price'] as num), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['title']?.toString() ?? 'Shop Mart', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(data['subtitle']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.shopping_bag_outlined, size: 48, color: Colors.white),
          ],
        ),
      );
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: const Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 44, color: AppTheme.textSecondary),
            SizedBox(height: 12),
            Text('Katalog sedang disiapkan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 5),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onTap, child: const Text('Coba lagi')),
            ],
          ),
        ),
      );
}
