import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/shop_repository.dart';
import '../widgets/product_card.dart';
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
    ]);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _data;
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
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Shop Mart', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                              SizedBox(height: 2),
                              Text('Koperasi Merah Putih Kerten', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                        Icon(Icons.notifications_none_rounded, color: AppTheme.textPrimary),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.search_rounded, size: 21, color: AppTheme.textSecondary),
                            SizedBox(width: 9),
                            Text('Cari produk koperasi...', style: TextStyle(color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<dynamic>>(
              future: _data,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: _StateMessage(
                      icon: Icons.cloud_off_outlined,
                      title: 'Gagal memuat Shop Mart',
                      subtitle: 'Periksa koneksi internet lalu coba lagi.',
                      action: 'Coba lagi',
                      onTap: () => setState(_reload),
                    ),
                  );
                }
                final banners = snapshot.data![0] as List<Map<String, dynamic>>;
                final categories = snapshot.data![1] as List<Map<String, dynamic>>;
                final products = snapshot.data![2] as List<Map<String, dynamic>>;
                return SliverList(
                  delegate: SliverChildListDelegate([
                    if (banners.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _PromoBanner(data: banners.first),
                      ),
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
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
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
                                  Text(
                                    category['name']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                      child: Text('Produk untuk Kamu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
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
                        itemBuilder: (_, i) => ProductCard(
                          product: products[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: products[i]['id'] as String)),
                          ),
                        ),
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

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
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
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 44, color: AppTheme.textSecondary),
          SizedBox(height: 12),
          Text('Katalog sedang disiapkan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          SizedBox(height: 5),
          Text('Pengelola koperasi dapat menambahkan produk dari menu Admin setelah masuk.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.title, required this.subtitle, required this.action, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 5),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 14),
            OutlinedButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}
