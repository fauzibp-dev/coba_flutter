import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminAuditScreen extends StatefulWidget {
  const SuperadminAuditScreen({super.key});

  @override
  State<SuperadminAuditScreen> createState() => _SuperadminAuditScreenState();
}

class _SuperadminAuditScreenState extends State<SuperadminAuditScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = SuperadminRepository.instance.auditLogs(limit: 300);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit Log', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat audit: ${friendlyError(snapshot.error!)}'));
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('Belum ada audit log.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = rows[i];
                final created = DateTime.tryParse(a['created_at']?.toString() ?? '');
                final newValue = a['new_value'];
                return Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(a['action']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))),
                          if (created != null) Text(_formatDate(created), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('${a['store_name'] ?? 'Platform'} • ${a['actor_email'] ?? 'system'}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      Text('${a['entity_type'] ?? '-'} • ${a['entity_id'] ?? '-'}', style: const TextStyle(fontSize: 12)),
                      if (newValue != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(color: const Color(0xFFF6F6F6), borderRadius: BorderRadius.circular(8)),
                          child: Text(const JsonEncoder.withIndent('  ').convert(newValue), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}
