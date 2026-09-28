import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap});

  final Map<String, dynamic> product;
  final VoidCallback onTap;

  String? get imageUrl {
    final images = product['product_images'];
    if (images is List && images.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(
        images.map((e) => Map<String, dynamic>.from(e as Map)),
      )..sort((a, b) => ((a['sort_order'] ?? 0) as num).compareTo((b['sort_order'] ?? 0) as num));
      return sorted.first['image_url'] as String?;
    }
    return null;
  }

  int get stock {
    final rows = product['inventory'];
    if (rows is! List) return 0;
    return rows.fold<int>(0, (sum, e) => sum + (((e as Map)['available_qty'] ?? 0) as num).toInt());
  }

  @override
  Widget build(BuildContext context) {
    final price = (product['price'] ?? 0) as num;
    final compare = product['compare_at_price'] as num?;
    final rating = (product['rating_average'] ?? 0) as num;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: imageUrl == null
                  ? Container(
                      color: const Color(0xFFF0F0F0),
                      child: const Icon(Icons.storefront_outlined, size: 44, color: Color(0xFFAAAAAA)),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFF0F0F0),
                        child: Icon(Icons.broken_image_outlined, color: Color(0xFFAAAAAA)),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name']?.toString() ?? '-',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.25, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    rupiah(price),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primary),
                  ),
                  if (compare != null && compare > price)
                    Text(
                      rupiah(compare),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const Spacer(),
                      Text('Stok $stock', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
