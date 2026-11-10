import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminOrdersScreen extends StatefulWidget {
  const SuperadminOrdersScreen({super.key});

  @override
  State<SuperadminOrdersScreen> createState() => _SuperadminOrdersScreenState();
}

class _SuperadminOrdersScreenState extends State<SuperadminOrdersScreen> {
  String? _storeId;
  String? _status;
  late Future<List<dynamic>> _future;

  static const _statusOptions = [
    'pending_payment',
    'paid',
    'confirmed',
    'processing',
    'ready_to_ship',
    'shipped',
    'delivered',
    'completed',
    'cancelled',
    'refund_pending',
    'refunded',
  ];

  static const Map<String, List<String>> _next = {
    'pending_payment': ['paid', 'cancelled'],
    'paid': ['confirmed', 'refund_pending'],
    'confirmed': ['processing', 'cancelled', 'refund_pending'],
    'processing': ['ready_to_ship', 'cancelled', 'refund_pending'],
    'ready_to_ship': ['shipped', 'cancelled', 'refund_pending'],
    'shipped': ['delivered', 'refund_pending'],
    'delivered': ['completed', 'refund_pending'],
    'completed': ['refund_pending'],
    'refund_pending': ['refunded'],
  };

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Future.wait([
      SuperadminRepository.instance.orders(storeId: _storeId, status: _status),
      SuperadminRepository.instance.stores(),
    ]);
  }

  Future<void> _changeStatus(Map<String, dynamic> order, String nextStatus) async {
    final note = TextEditingController(text: 'Diubah oleh Platform Super Admin');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ubah Status Pesanan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order['order_number']}\n${order['status']} → $nextStatus', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan audit')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Konfirmasi')),
        ],
      ),
    );
    if (confirm != true) {
      note.dispose();
      return;
    }
    try {
      await SuperadminRepository.instance.updateOrderStatus(order['id'].toString(), nextStatus, note: note.text.trim());
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      note.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pesanan Global', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat order: ${friendlyError(snapshot.error!)}'));
          final orders = snapshot.data![0] as List<Map<String, dynamic>>;
          final stores = snapshot.data![1] as List<Map<String, dynamic>>;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _storeId ?? '_all',
                        decoration: const InputDecoration(labelText: 'Toko'),
                        items: [
                          const DropdownMenuItem(value: '_all', child: Text('Semua toko')),
                          ...stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-'))),
                        ],
                        onChanged: (v) => setState(() {
                          _storeId = v == '_all' ? null : v;
                          _reload();
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _status ?? '_all',
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: [
                          const DropdownMenuItem(value: '_all', child: Text('Semua status')),
                          ..._statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))),
                        ],
                        onChanged: (v) => setState(() {
                          _status = v == '_all' ? null : v;
                          _reload();
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: orders.isEmpty
                    ? const Center(child: Text('Belum ada pesanan pada filter ini.'))
                    : RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: orders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final o = orders[i];
                            final current = o['status']?.toString() ?? '';
                            final nextStatuses = _next[current] ?? const <String>[];
                            return Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(o['order_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))),
                                      Text(rupiah((o['total_amount'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${o['store_name']} • ${o['customer_email'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 4),
                                  Text('${o['item_count'] ?? 0} item • ${o['payment_method']} / ${o['payment_status']} • ${o['shipping_method']}', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Chip(label: Text(current.replaceAll('_', ' '))),
                                      const Spacer(),
                                      if (nextStatuses.isNotEmpty)
                                        PopupMenuButton<String>(
                                          tooltip: 'Proses status',
                                          onSelected: (value) => _changeStatus(o, value),
                                          itemBuilder: (_) => nextStatuses
                                              .map((s) => PopupMenuItem(value: s, child: Text('Ubah ke ${s.replaceAll('_', ' ')}')))
                                              .toList(),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.sync_alt_rounded, size: 18), SizedBox(width: 5), Text('Proses')]),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
