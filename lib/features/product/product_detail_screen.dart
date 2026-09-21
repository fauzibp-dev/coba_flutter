import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  final Product product;
  final VoidCallback onAddToCart;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int selectedVariant = 0;
  bool favorite = false;

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Detail Produk', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: () => setState(() => favorite = !favorite),
            icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: favorite ? AppTheme.primary : null),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.shopping_cart_outlined)),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        children: [
          Container(
            height: 320,
            color: product.color,
            child: Center(
              child: Icon(product.icon, size: 126, color: AppTheme.textPrimary.withValues(alpha: 0.72)),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(rupiah(product.price), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppTheme.primary)),
                    const SizedBox(width: 8),
                    Text(
                      rupiah(product.oldPrice),
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough),
                    ),
                    if (product.discountLabel != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFECEA), borderRadius: BorderRadius.circular(5)),
                        child: Text(product.discountLabel!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(product.name, style: const TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF4A825), size: 18),
                    const SizedBox(width: 4),
                    Text('${product.rating}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    const Text('124 ulasan', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    const Text('•', style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    Text('${product.sold} terjual', style: const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _section(
            title: 'Voucher Koperasi',
            child: Row(
              children: [
                _tag('HEMAT10'),
                const SizedBox(width: 8),
                _tag('ONGKIR5K'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _section(
            title: 'Pengiriman',
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.local_shipping_outlined, size: 20, color: AppTheme.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dikirim dari Koperasi Merah Putih Kerten', style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Estimasi 1–2 hari • Mulai Rp5.000', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _section(
            title: 'Pilih Varian',
            child: Wrap(
              spacing: 8,
              children: List.generate(3, (index) {
                final labels = ['Regular', 'Hemat', 'Paket 2'];
                return ChoiceChip(
                  label: Text(labels[index]),
                  selected: selectedVariant == index,
                  onSelected: (_) => setState(() => selectedVariant = index),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          _section(
            title: 'Deskripsi Produk',
            child: Text(product.description, style: const TextStyle(fontSize: 14, height: 1.6, color: AppTheme.textSecondary)),
          ),
          const SizedBox(height: 8),
          _section(
            title: 'Ulasan Pembeli',
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('4.9', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('★★★★★', style: TextStyle(color: Color(0xFFF4A825), letterSpacing: 1)),
                        Text('124 ulasan terverifikasi', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Text('“Barang sesuai, pengemasan rapi dan pengiriman cepat.”', style: TextStyle(height: 1.5)),
                SizedBox(height: 6),
                Text('— Pembeli terverifikasi', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 88),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: IconButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat Koperasi dibuka (preview)'))),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    widget.onAddToCart();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk ditambahkan ke keranjang')));
                  },
                  icon: const Icon(Icons.add_shopping_cart_outlined),
                  label: const Text('Keranjang'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Masuk ke checkout (preview)'))),
                  child: const Text('Beli Sekarang'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1EF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFFFC7C2)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
    );
  }
}
