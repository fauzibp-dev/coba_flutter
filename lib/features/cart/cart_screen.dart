import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int riceQty = 1;
  int oilQty = 2;

  @override
  Widget build(BuildContext context) {
    final subtotal = (products[0].price * riceQty) + (products[1].price * oilQty);
    final shipping = 5000;
    final total = subtotal + shipping;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            alignment: Alignment.centerLeft,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Keranjang', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Produk dari Koperasi Merah Putih Kerten', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _cartItem(products[0], riceQty, (delta) {
                  setState(() => riceQty = (riceQty + delta).clamp(1, 99));
                }),
                const SizedBox(height: 10),
                _cartItem(products[1], oilQty, (delta) {
                  setState(() => oilQty = (oilQty + delta).clamp(1, 99));
                }),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_offer_outlined, color: AppTheme.primary),
                      SizedBox(width: 10),
                      Expanded(child: Text('Voucher Shop Mart', style: TextStyle(fontWeight: FontWeight.w700))),
                      Text('Pilih voucher', style: TextStyle(color: AppTheme.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                _summaryRow('Subtotal', rupiah(subtotal)),
                const SizedBox(height: 6),
                _summaryRow('Estimasi ongkir', rupiah(shipping)),
                const Divider(height: 22),
                Row(
                  children: [
                    const Expanded(child: Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
                    Text(rupiah(total), style: const TextStyle(fontSize: 20, color: AppTheme.primary, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _showCheckout(context, total),
                  child: const Text('Lanjut Checkout'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cartItem(Product product, int qty, ValueChanged<int> onChange) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(color: product.color, borderRadius: BorderRadius.circular(10)),
            child: Icon(product.icon, size: 40, color: AppTheme.textPrimary.withValues(alpha: 0.72)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3)),
                const SizedBox(height: 6),
                const Text('Varian: Regular', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Text(rupiah(product.price), style: const TextStyle(fontSize: 16, color: AppTheme.primary, fontWeight: FontWeight.w800))),
                    _qtyButton(Icons.remove, () => onChange(-1)),
                    SizedBox(width: 30, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700))),
                    _qtyButton(Icons.add, () => onChange(1)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(border: Border.all(color: AppTheme.border), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 17),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showCheckout(BuildContext context, int total) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(99))),
                ),
                const SizedBox(height: 18),
                const Text('Preview Checkout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 16),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.location_on_outlined, color: AppTheme.primary),
                  title: Text('Fauzi • 08xxxxxxxxxx', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Kerten, Laweyan, Surakarta'),
                  trailing: Icon(Icons.chevron_right_rounded),
                ),
                const Divider(height: 24),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.local_shipping_outlined, color: AppTheme.primary),
                  title: Text('Local Delivery', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Estimasi 1–2 hari'),
                  trailing: Text('Rp5.000'),
                ),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.payments_outlined, color: AppTheme.primary),
                  title: Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Transfer Bank / COD (preview)'),
                  trailing: Icon(Icons.chevron_right_rounded),
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Expanded(child: Text('Total pembayaran', style: TextStyle(fontWeight: FontWeight.w700))),
                    Text(rupiah(total), style: const TextStyle(fontSize: 20, color: AppTheme.primary, fontWeight: FontWeight.w900)),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Checkout berhasil disimulasikan')));
                  },
                  child: const Text('Buat Pesanan'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
