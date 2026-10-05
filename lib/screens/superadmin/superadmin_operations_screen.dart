import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_operations_repository.dart';
import '../../services/superadmin_repository.dart';

class SuperadminOperationsScreen extends StatefulWidget {
  const SuperadminOperationsScreen({super.key});

  @override
  State<SuperadminOperationsScreen> createState() => _SuperadminOperationsScreenState();
}

class _SuperadminOperationsScreenState extends State<SuperadminOperationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<dynamic>> _future;
  String? _storeFilter;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    _future = Future.wait([
      SuperadminRepository.instance.stores(),
      SuperadminOperationsRepository.instance.integrations(storeId: _storeFilter),
      SuperadminOperationsRepository.instance.syncLogs(),
    ]);
  }

  Future<void> _sendAnnouncement(List<Map<String, dynamic>> stores) async {
    final title = TextEditingController();
    final body = TextEditingController();
    var target = '_all';
    var type = 'announcement';
    var sending = false;

    final sent = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kirim Notifikasi'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: target,
                    decoration: const InputDecoration(labelText: 'Penerima'),
                    items: [
                      const DropdownMenuItem(value: '_all', child: Text('Semua pengguna')),
                      ...stores.map(
                        (s) => DropdownMenuItem(
                          value: s['id'].toString(),
                          child: Text('Pelanggan/pengelola • ${s['name'] ?? '-'}'),
                        ),
                      ),
                    ],
                    onChanged: sending ? null : (v) => setDialogState(() => target = v ?? '_all'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Jenis'),
                    items: const [
                      DropdownMenuItem(value: 'announcement', child: Text('Pengumuman')),
                      DropdownMenuItem(value: 'promo', child: Text('Promo')),
                      DropdownMenuItem(value: 'system', child: Text('Sistem')),
                    ],
                    onChanged: sending ? null : (v) => setDialogState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: title,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: 'Judul *'),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: const InputDecoration(labelText: 'Pesan *'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      if (title.text.trim().isEmpty || body.text.trim().isEmpty) return;
                      setDialogState(() => sending = true);
                      try {
                        final count = await SuperadminOperationsRepository.instance.sendNotification(
                          storeId: target == '_all' ? null : target,
                          title: title.text,
                          body: body.text,
                          type: type,
                        );
                        if (context.mounted) Navigator.pop(context, count);
                      } catch (e) {
                        setDialogState(() => sending = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(friendlyError(e))),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.send_rounded),
              label: Text(sending ? 'Mengirim...' : 'Kirim'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    body.dispose();
    if (sent != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notifikasi terkirim ke $sent akun.')),
      );
    }
  }

  Future<void> _editIntegration(
    List<Map<String, dynamic>> stores, [
    Map<String, dynamic>? integration,
  ]) async {
    if (stores.isEmpty) return;
    var storeId = integration?['store_id']?.toString() ?? stores.first['id'].toString();
    final name = TextEditingController(text: integration?['name']?.toString() ?? '');
    final type = TextEditingController(text: integration?['source_type']?.toString() ?? 'rest_api');
    final baseUrl = TextEditingController(text: integration?['base_url']?.toString() ?? '');
    var active = integration?['is_active'] == true;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(integration == null ? 'Tambah Integrasi' : 'Edit Integrasi'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: storeId,
                    decoration: const InputDecoration(labelText: 'Toko *'),
                    items: stores
                        .map(
                          (s) => DropdownMenuItem(
                            value: s['id'].toString(),
                            child: Text(s['name']?.toString() ?? '-'),
                          ),
                        )
                        .toList(),
                    onChanged: integration != null || saving
                        ? null
                        : (v) => setDialogState(() => storeId = v ?? storeId),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nama integrasi *'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: type,
                    decoration: const InputDecoration(
                      labelText: 'Tipe sumber *',
                      hintText: 'rest_api / webhook / legacy_ecommerce',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: baseUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://...',
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif'),
                    subtitle: const Text('Aktifkan hanya setelah endpoint dan source-of-truth sudah dikonfirmasi.'),
                    value: active,
                    onChanged: saving ? null : (v) => setDialogState(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (name.text.trim().isEmpty || type.text.trim().isEmpty) return;
                      setDialogState(() => saving = true);
                      try {
                        await SuperadminOperationsRepository.instance.saveIntegration(
                          id: integration?['id']?.toString(),
                          storeId: storeId,
                          name: name.text,
                          sourceType: type.text,
                          baseUrl: baseUrl.text,
                          isActive: active,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(friendlyError(e))),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    type.dispose();
    baseUrl.dispose();
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Operations Center', style: TextStyle(fontWeight: FontWeight.w900)),
            Text('Broadcast, integrasi, dan sinkronisasi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Broadcast'),
            Tab(text: 'Integrasi'),
            Tab(text: 'Sync Log'),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat operasi: ${friendlyError(snapshot.error!)}'));
          }
          final stores = snapshot.data![0] as List<Map<String, dynamic>>;
          final integrations = snapshot.data![1] as List<Map<String, dynamic>>;
          final logs = snapshot.data![2] as List<Map<String, dynamic>>;
          return TabBarView(
            controller: _tabs,
            children: [
              _BroadcastTab(stores: stores, onSend: () => _sendAnnouncement(stores)),
              _IntegrationsTab(
                stores: stores,
                integrations: integrations,
                storeFilter: _storeFilter,
                onFilterChanged: (value) => setState(() {
                  _storeFilter = value;
                  _reload();
                }),
                onAdd: () => _editIntegration(stores),
                onEdit: (row) => _editIntegration(stores, row),
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                },
              ),
              _SyncLogsTab(
                logs: logs,
                onRefresh: () async {
                  setState(_reload);
                  await _future;
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BroadcastTab extends StatelessWidget {
  const _BroadcastTab({required this.stores, required this.onSend});
  final List<Map<String, dynamic>> stores;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_active_outlined, color: AppTheme.primary),
                  SizedBox(width: 8),
                  Text('Broadcast Notifikasi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              SizedBox(height: 8),
              Text(
                'Kirim pengumuman ke semua akun atau audience yang pernah bertransaksi / menjadi pengelola pada toko tertentu. Semua pengiriman dicatat ke Audit Log.',
                style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onSend,
          icon: const Icon(Icons.send_rounded),
          label: const Text('Buat Broadcast'),
        ),
        const SizedBox(height: 14),
        Text('${stores.length} toko tersedia sebagai target.', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      ],
    );
  }
}

class _IntegrationsTab extends StatelessWidget {
  const _IntegrationsTab({
    required this.stores,
    required this.integrations,
    required this.storeFilter,
    required this.onFilterChanged,
    required this.onAdd,
    required this.onEdit,
    required this.onRefresh,
  });

  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> integrations;
  final String? storeFilter;
  final ValueChanged<String?> onFilterChanged;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: storeFilter ?? '_all',
                  decoration: const InputDecoration(labelText: 'Filter toko'),
                  items: [
                    const DropdownMenuItem(value: '_all', child: Text('Semua toko')),
                    ...stores.map(
                      (s) => DropdownMenuItem(
                        value: s['id'].toString(),
                        child: Text(s['name']?.toString() ?? '-'),
                      ),
                    ),
                  ],
                  onChanged: (v) => onFilterChanged(v == '_all' ? null : v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Tambah integrasi',
                onPressed: stores.isEmpty ? null : onAdd,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: integrations.isEmpty
              ? const Center(child: Text('Belum ada integration source.'))
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: integrations.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final row = integrations[i];
                      final active = row['is_active'] == true;
                      final lastSync = DateTime.tryParse(row['last_sync_at']?.toString() ?? '');
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: ListTile(
                          onTap: () => onEdit(row),
                          leading: CircleAvatar(
                            backgroundColor: active ? const Color(0xFFE7F5E9) : const Color(0xFFF2F2F2),
                            child: Icon(
                              active ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                              color: active ? const Color(0xFF2E7D32) : AppTheme.textSecondary,
                            ),
                          ),
                          title: Text(row['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            '${row['store_name']} • ${row['source_type']}\n${active ? 'Aktif' : 'Nonaktif'} • mapping ${row['mapping_count'] ?? 0} • sync ${row['sync_count'] ?? 0}${lastSync == null ? '' : ' • ${DateFormat('dd MMM HH:mm', 'id_ID').format(lastSync.toLocal())}'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.edit_outlined),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _SyncLogsTab extends StatelessWidget {
  const _SyncLogsTab({required this.logs, required this.onRefresh});
  final List<Map<String, dynamic>> logs;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Center(child: Text('Belum ada sync log. Integrasi belum melakukan sinkronisasi.'));
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final row = logs[i];
          final time = DateTime.tryParse(row['created_at']?.toString() ?? '');
          final status = row['status']?.toString() ?? '-';
          final ok = status.toLowerCase() == 'success' || status.toLowerCase() == 'completed';
          return Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ok ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded, color: ok ? const Color(0xFF2E7D32) : AppTheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${row['source_name'] ?? 'Unknown source'} • $status', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('${row['direction'] ?? '-'} • ${row['entity_type'] ?? '-'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      if (row['detail'] != null) ...[
                        const SizedBox(height: 4),
                        Text(row['detail'].toString(), maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                      ],
                      if (time != null) ...[
                        const SizedBox(height: 4),
                        Text(DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(time.toLocal()), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
