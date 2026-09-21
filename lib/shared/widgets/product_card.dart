import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    required this.onAdd,
  });

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: product.color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(product.icon, size: 62, color: AppTheme.textPrimary.withValues(alpha: 0.72)),
                    ),
                    if (product.discountLabel != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.discountLabel!,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, height: 1.25, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    rupiah(product.price),
                    style: const TextStyle(fontSize: 16, color: AppTheme.primary, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF4A825)),
                      const SizedBox(width: 2),
                      Text('${product.rating}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${product.sold} terjual',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ),
                      InkWell(
                        onTap: onAdd,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.add_shopping_cart_outlined, size: 19, color: AppTheme.primary),
                        ),
                      ),
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
