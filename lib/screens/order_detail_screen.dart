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

  String _date(dynamic raw) {
    final value = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (value == null) return '-';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(value);
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
      'refund_pending': 'Refund Diproses',
      'refunded': 'Refund Selesai',
    };
    return labels[value] ?? value.replaceAll('_', ' ');
  }

  bool _hasReview(Map<String, dynamic> item) {
    final raw = item['reviews'];
    if (raw is List) return raw.isNotEmpty;
    return raw is Map;
  }

  Future<void> _review(Map<String, dynamic> item) async {
    final productId = item['product_id']?.toString();
    if (productId == null || productId.isEmpty) return;
    var rating = 5;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Ulas ${item['product_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rating'),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    onPressed: () => setLocal(() => rating = value),
                    icon: Icon(value <= rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF5A623)),
                  );
                }),
              ),
              TextField(controller: comment, maxLines: 3, decoration: const InputDecoration(labelText: 'Komentar (opsional)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kirim Ulasan')),
          ],
        ),
      ),
    );
    if (ok != true) {
      comment.dispose();
      return;
    }
    try {
      await ShopRepository.instance.submitReview(
        orderItemId: item['id'] as String,
        productId: productId,
        rating: rating,
        comment: comment.text,
      );
      if (mounted) {
        setState(_reload);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ulasan berhasil disimpan.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      comment.dispose();
    }
  }

  Future<void> _requestReturn(Map<String, dynamic> order) async {
    final reason = TextEditingController();
    final description = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ajukan Retur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: reason, decoration: const InputDecoration(labelText: 'Alasan retur')),
            const SizedBox(height: 10),
            TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Penjelasan (opsional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              if (reason.text.trim().length < 3) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Ajukan'),
          ),
        ],
      ),
    );
    if (ok != true) {
      reason.dispose();
      description.dispose();
      return;
    }
    try {
      await ShopRepository.instance.requestReturn(
        orderId: order['id'] as String,
        reason: reason.text,
        description: description.text,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan retur berhasil dikirim.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      reason.dispose();
      description.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text('Pesanan tidak dapat dimuat: ${snapshot.hasError ? friendlyError(snapshot.error!) : ''}'));
          }
          final order = snapshot.data!;
          final items = (order['order_items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final history = (order['order_status_history'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList()
            ..sort((a, b) => (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));
          final payments = (order['payments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final status = order['status']?.toString() ?? '';
          final address = order['address_snapshot'] is Map ? Map<String, dynamic>.from(order['address_snapshot'] as Map) : null;
          final canReview = status == 'completed';
          final canReturn = status == 'delivered' || status == 'completed';

          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(order['order_number']?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                          _Badge(text: _status(status), danger: status == 'cancelled' || status == 'refunded'),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text('Dibuat ${_date(order['created_at'])}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const Divider(height: 24),
                      _Row(label: 'Pembayaran', value: order['payment_method'] == 'cod' ? 'COD' : 'Transfer manual'),
                      _Row(label: 'Status bayar', value: order['payment_status']?.toString().replaceAll('_', ' ') ?? '-'),
                      _Row(label: 'Pengiriman', value: order['shipping_method'] == 'pickup' ? 'Ambil di koperasi' : 'Local Delivery'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  title: 'Produk',
                  child: Column(
                    children: items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(child: Text('${item['product_name']} ×${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                                Text(rupiah((item['subtotal'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w800)),
                              ],
                            ),
                            if (item['variant_name'] != null) Text(item['variant_name'].toString(), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            if (canReview && item['product_id'] != null) ...[
                              const SizedBox(height: 7),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () => _review(item),
                                  icon: Icon(_hasReview(item) ? Icons.edit_outlined : Icons.star_border_rounded),
                                  label: Text(_hasReview(item) ? 'Edit Ulasan' : 'Beri Ulasan'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                _Card(
                  title: 'Ringkasan Pembayaran',
                  child: Column(
                    children: [
                      _Row(label: 'Subtotal', value: rupiah((order['subtotal'] ?? 0) as num)),
                      _Row(label: 'Diskon', value: '-${rupiah((order['discount_amount'] ?? 0) as num)}'),
                      _Row(label: 'Pengiriman', value: rupiah((order['shipping_cost'] ?? 0) as num)),
                      const Divider(height: 22),
                      _Row(label: 'Total', value: rupiah((order['total_amount'] ?? 0) as num), bold: true),
                      if (payments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Payment: ${payments.first['status'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                ),
                if (address != null) ...[
                  const SizedBox(height: 12),
                  _Card(
                    title: 'Alamat Pengiriman',
                    child: Text(
                      '${address['recipient_name'] ?? ''} • ${address['phone'] ?? ''}\n${address['address_line'] ?? ''}, ${address['district'] ?? ''}, ${address['city'] ?? ''}, ${address['province'] ?? ''}',
                      style: const TextStyle(height: 1.5),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _Card(
                  title: 'Riwayat Status',
                  child: history.isEmpty
                      ? const Text('Belum ada riwayat status.', style: TextStyle(color: AppTheme.textSecondary))
                      : Column(
                          children: history.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 3),
                                    child: Icon(Icons.circle, size: 10, color: AppTheme.primary),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(_status(entry['status']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800)),
                                        Text(_date(entry['created_at']), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                        if (entry['note']?.toString().trim().isNotEmpty == true)
                                          Text(entry['note'].toString(), style: const TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                if (canReturn) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _requestReturn(order),
                    icon: const Icon(Icons.assignment_return_outlined),
                    label: const Text('Ajukan Retur'),
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
}

class _Card extends StatelessWidget {
  const _Card({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
          ],
          child,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: bold ? AppTheme.textPrimary : AppTheme.textSecondary, fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
          const SizedBox(width: 12),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: bold ? AppTheme.primary : null)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.danger});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppTheme.primary : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}
