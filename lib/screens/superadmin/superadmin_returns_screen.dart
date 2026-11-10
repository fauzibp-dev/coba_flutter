import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminReturnsScreen extends StatefulWidget {
  const SuperadminReturnsScreen({super.key});

  @override
  State<SuperadminReturnsScreen> createState() => _SuperadminReturnsScreenState();
}

class _SuperadminReturnsScreenState extends State<SuperadminReturnsScreen> {
  String? _storeId;
  late Future<List<dynamic>> _future;

  static const _statuses = [
    'requested',
    'reviewing',
    'approved',
    'rejected',
    'item_returning',
    'item_received',
    'refunded',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Future.wait([
      SuperadminRepository.instance.returns(storeId: _storeId),
      SuperadminRepository.instance.stores(),
    ]);
  }

  Future<void> _change(Map<String, dynamic> item, String status) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Retur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${item['order_number']}\n${item['status']} → $status', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'Catatan audit')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) {
      note.dispose();
      return;
    }
    try {
      await SuperadminRepository.instance.updateReturnStatus(item['id'].toString(), status, note: note.text.trim());
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
      appBar: AppBar(title: const Text('Retur & After Sales', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat retur: ${friendlyError(snapshot.error!)}'));
          final returns = snapshot.data![0] as List<Map<String, dynamic>>;
          final stores = snapshot.data![1] as List<Map<String, dynamic>>;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: DropdownButtonFormField<String>(
                  initialValue: _storeId ?? '_all',
                  decoration: const InputDecoration(labelText: 'Filter toko'),
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
              Expanded(
                child: returns.isEmpty
                    ? const Center(child: Text('Belum ada permintaan retur.'))
                    : RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: returns.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = returns[i];
                            final current = r['status']?.toString() ?? 'requested';
                            return Container(
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(r['order_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))),
                                      Chip(label: Text(current.replaceAll('_', ' '))),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${r['store_name']} • ${r['customer_email'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 8),
                                  Text('Alasan: ${r['reason'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                  if (r['description']?.toString().isNotEmpty == true) ...[
                                    const SizedBox(height: 4),
                                    Text(r['description'].toString(), style: const TextStyle(fontSize: 12)),
                                  ],
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    initialValue: _statuses.contains(current) ? current : 'requested',
                                    decoration: const InputDecoration(labelText: 'Status retur'),
                                    items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                                    onChanged: (v) {
                                      if (v != null && v != current) _change(r, v);
                                    },
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
