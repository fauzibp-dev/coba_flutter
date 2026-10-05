import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';
import 'order_detail_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = ShopRepository.instance.myOrders();

  Future<void> _open(String id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: id)));
    if (mounted) setState(_reload);
  }

  Future<void> _cancel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan pesanan?'),
        content: const Text('Stok akan dikembalikan ke katalog. Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Batalkan Pesanan')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ShopRepository.instance.cancelOrder(id, reason: 'Dibatalkan pelanggan dari aplikasi');
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  String _status(String value) {
    const labels = {
      'pending_payment': 'Menunggu Pembayaran',
      'paid': 'Sudah Dibayar',
      'confirmed': 'Dikonfirmasi',
      'processing': 'Sedang Diproses',
      'ready_to_ship': 'Siap Dikirim',
      'shipped': 'Dikirim',
      'delivered': 'Sudah Tiba',
      'completed': 'Selesai',
      'cancelled': 'Dibatalkan',
      'return_requested': 'Pengembalian Diajukan',
      'returned': 'Dikembalikan',
      'refund_pending': 'Refund Diproses',
      'refunded': 'Refund Selesai',
    };
    return labels[value] ?? value;
  }

  String _date(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    return date == null ? '' : DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(
      bottom: false,
      child: Column(
        children: [
          if (widget.embedded)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              child: const Text('Pesanan Saya', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(_reload);
                await _future;
              },
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError) return const Center(child: Text('Gagal memuat pesanan.'));
                  final orders = snapshot.data ?? [];
                  if (orders.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 150),
                        Icon(Icons.receipt_long_outlined, size: 56, color: AppTheme.textSecondary),
                        SizedBox(height: 12),
                        Center(child: Text('Belum ada pesanan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                        SizedBox(height: 5),
                        Center(child: Text('Pesanan yang dibuat akan muncul di sini.', style: TextStyle(color: AppTheme.textSecondary))),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final order = orders[i];
                      final items = order['order_items'] as List? ?? [];
                      final status = order['status']?.toString() ?? '';
                      return InkWell(
                        onTap: () => _open(order['id'] as String),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(order['order_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))),
                                  _StatusBadge(label: _status(status), danger: status == 'cancelled'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(_date(order['created_at']), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                              const Divider(height: 22),
                              ...items.take(3).map((raw) {
                                final item = Map<String, dynamic>.from(raw as Map);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 7),
                                  child: Row(
                                    children: [
                                      Expanded(child: Text('${item['product_name']} ×${item['quantity']}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      Text(rupiah((item['subtotal'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                );
                              }),
                              if (items.length > 3) Text('+${items.length - 3} produk lainnya', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              const Divider(height: 22),
                              Row(
                                children: [
                                  const Text('Total', style: TextStyle(color: AppTheme.textSecondary)),
                                  const Spacer(),
                                  Text(rupiah((order['total_amount'] ?? 0) as num), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.primary)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${order['shipping_method'] == 'pickup' ? 'Ambil di koperasi' : 'Local Delivery'} • ${order['payment_method'] == 'cod' ? 'COD' : 'Transfer manual'} • Ketuk untuk detail',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              if (status == 'pending_payment' || status == 'confirmed') ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: () => _cancel(order['id'] as String),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.primary),
                                    child: const Text('Batalkan Pesanan'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Pesanan')), body: body);
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.danger});
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.primary : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
