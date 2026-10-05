import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = ShopRepository.instance.orderDetail(widget.orderId);

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
    return labels[value] ?? value.replaceAll('_', ' ');
  }

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    return d == null ? '-' : DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(d.toLocal());
  }

  Future<void> _review(Map<String, dynamic> item) async {
    final orderItemId = item['id'] as String;
    final productId = item['product_id'] as String?;
    if (productId == null) return;
    final existing = await ShopRepository.instance.reviewForOrderItem(orderItemId);
    if (!mounted) return;
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk ini sudah kamu ulas.')));
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReviewDialog(item: item),
    );
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _requestReturn() async {
    final reason = TextEditingController();
    final detail = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajukan Pengembalian'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Alasan')),
            const SizedBox(height: 10),
            TextField(controller: detail, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Detail (opsional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ShopRepository.instance.requestReturn(
          orderId: widget.orderId,
          reason: reason.text,
          description: detail.text,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan pengembalian terkirim.')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    reason.dispose();
    detail.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData) return const Center(child: Text('Detail pesanan tidak dapat dimuat.'));
          final order = snapshot.data!;
          final items = (order['order_items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final history = (order['order_status_history'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            ..sort((a, b) => (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));
          final address = order['address_snapshot'];
          final status = order['status']?.toString() ?? '';
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(order['order_number']?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                          _Badge(label: _status(status)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_date(order['created_at']), style: const TextStyle(color: AppTheme.textSecondary)),
                      const Divider(height: 24),
                      _row('Pembayaran', order['payment_method'] == 'cod' ? 'COD' : 'Transfer manual'),
                      _row('Status bayar', _status(order['payment_status']?.toString() ?? '-')),
                      _row('Pengiriman', order['shipping_method'] == 'pickup' ? 'Ambil di koperasi' : 'Local Delivery'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text('${item['product_name']} ×${item['quantity']}')),
                                    Text(rupiah((item['subtotal'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                if (status == 'completed' && item['product_id'] != null)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      onPressed: () => _review(item),
                                      icon: const Icon(Icons.star_border_rounded),
                                      label: const Text('Beri Ulasan'),
                                    ),
                                  ),
                              ],
                            ),
                          )),
                      const Divider(),
                      _row('Subtotal', rupiah((order['subtotal'] ?? 0) as num)),
                      _row('Diskon', '- ${rupiah((order['discount_amount'] ?? 0) as num)}'),
                      _row('Pengiriman', rupiah((order['shipping_cost'] ?? 0) as num)),
                      const Divider(),
                      _row('Total', rupiah((order['total_amount'] ?? 0) as num), bold: true),
                    ],
                  ),
                ),
                if (address is Map) ...[
                  const SizedBox(height: 12),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Alamat Pengiriman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Text('${address['recipient_name']} • ${address['phone']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${address['address_line']}, ${address['district']}, ${address['city']}, ${address['province']}'),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Timeline Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      if (history.isEmpty)
                        const Text('Belum ada histori status.', style: TextStyle(color: AppTheme.textSecondary))
                      else
                        ...history.map((h) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 2),
                                    child: Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.success),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_status(h['status']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        if (h['note'] != null) Text(h['note'].toString(), style: const TextStyle(fontSize: 12)),
                                        Text(_date(h['created_at']), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )),
                    ],
                  ),
                ),
                if (status == 'delivered' || status == 'completed') ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _requestReturn,
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Ajukan Pengembalian / Refund'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: bold ? null : AppTheme.textSecondary, fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? AppTheme.primary : null)),
          ],
        ),
      );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.item});
  final Map<String, dynamic> item;

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _saving = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ShopRepository.instance.submitReview(
        orderItemId: widget.item['id'] as String,
        productId: widget.item['product_id'] as String,
        rating: _rating,
        comment: _comment.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ulas ${widget.item['product_name']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            children: List.generate(
              5,
              (i) => IconButton(
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF5A623)),
              ),
            ),
          ),
          TextField(controller: _comment, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Komentar (opsional)')),
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Kirim Ulasan')),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: child,
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)),
      );
}
