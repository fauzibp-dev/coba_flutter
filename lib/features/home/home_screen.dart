import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';
import '../../shared/widgets/product_card.dart';
import '../product/product_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onAddToCart,
    required this.cartCount,
  });

  final VoidCallback onAddToCart;
  final int cartCount;

  void _openProduct(BuildContext context, Product product) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          onAddToCart: onAddToCart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Shop Mart',
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Koperasi Merah Putih Kerten',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(onPressed: () {}, icon: const Icon(Icons.shopping_cart_outlined)),
                          if (cartCount > 0)
                            Positioned(
                              right: 3,
                              top: 2,
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                                alignment: Alignment.center,
                                child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    readOnly: true,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pencarian aktif pada tahap berikutnya'))),
                    decoration: const InputDecoration(
                      hintText: 'Cari beras, minyak, kopi, kebutuhan rumah...',
                      prefixIcon: Icon(Icons.search_rounded),
                      suffixIcon: Icon(Icons.tune_rounded),
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Container(
                height: 152,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Belanja kebutuhan\nharian lebih mudah', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
                          SizedBox(height: 8),
                          Text('Produk koperasi, harga jelas, belanja praktis.', style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
                        ],
                      ),
                    ),
                    Container(
                      width: 86,
                      height: 86,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_basket_rounded, color: Colors.white, size: 46),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Kategori', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                  TextButton(onPressed: () {}, child: const Text('Lihat semua')),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 94,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  return SizedBox(
                    width: 66,
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(color: category.color, borderRadius: BorderRadius.circular(14)),
                          child: Icon(category.icon, color: AppTheme.textPrimary, size: 27),
                        ),
                        const SizedBox(height: 6),
                        Text(category.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: AppTheme.primary, size: 22),
                  const SizedBox(width: 4),
                  const Text('Flash Sale', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 9),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFFFFECEA), borderRadius: BorderRadius.circular(6)),
                    child: const Text('01 : 32 : 54', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return SizedBox(
                    width: 155,
                    child: ProductCard(
                      product: product,
                      onTap: () => _openProduct(context, product),
                      onAdd: onAddToCart,
                    ),
                  );
                },
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 22, 16, 10),
              child: Text('Rekomendasi untuk kamu', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final product = products[index];
                  return ProductCard(
                    product: product,
                    onTap: () => _openProduct(context, product),
                    onAdd: onAddToCart,
                  );
                },
                childCount: products.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
