import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/mock_data.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                Text('Pesanan Saya', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Pantau proses belanja dari pembayaran sampai selesai.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          SizedBox(
            height: 54,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              scrollDirection: Axis.horizontal,
              children: const [
                _FilterChip(label: 'Semua', selected: true),
                _FilterChip(label: 'Belum Bayar'),
                _FilterChip(label: 'Diproses'),
                _FilterChip(label: 'Dikirim'),
                _FilterChip(label: 'Selesai'),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: orderSummaries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = orderSummaries[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(order.number, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: order.statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(order.status, style: TextStyle(fontSize: 11, color: order.statusColor, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      Row(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(color: products[index].color, borderRadius: BorderRadius.circular(9)),
                            child: Icon(products[index].icon, size: 32, color: AppTheme.textPrimary.withValues(alpha: 0.72)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(order.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                const Text('Koperasi Merah Putih Kerten', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 22),
                      Row(
                        children: [
                          const Expanded(child: Text('Total Pesanan', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
                          Text(rupiah(order.total), style: const TextStyle(fontSize: 16, color: AppTheme.primary, fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Spacer(),
                          if (index == 0)
                            OutlinedButton(onPressed: () {}, child: const Text('Hubungi Koperasi'))
                          else
                            OutlinedButton(onPressed: () {}, child: const Text('Beli Lagi')),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 18)),
                            onPressed: () {},
                            child: Text(index == 0 ? 'Lacak Pesanan' : 'Beri Ulasan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? AppTheme.primary : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.textSecondary),
        ),
      ),
    );
  }
}
