import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../services/shop_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = ShopRepository.instance.notifications();

  Future<void> _open(Map<String, dynamic> row) async {
    if (row['is_read'] != true) {
      await ShopRepository.instance.markNotificationRead(row['id'] as String);
      if (mounted) setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return const Center(child: Text('Notifikasi tidak dapat dimuat.'));
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 54, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text('Belum ada notifikasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    SizedBox(height: 5),
                    Text('Update pesanan akan muncul di sini.', style: TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(_reload);
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final row = rows[i];
                final read = row['is_read'] == true;
                final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
                return Container(
                  decoration: BoxDecoration(
                    color: read ? Colors.white : const Color(0xFFFFF5F5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ListTile(
                    onTap: () => _open(row),
                    leading: Icon(
                      read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                      color: read ? AppTheme.textSecondary : AppTheme.primary,
                    ),
                    title: Text(row['title']?.toString() ?? 'Notifikasi', style: TextStyle(fontWeight: read ? FontWeight.w600 : FontWeight.w900)),
                    subtitle: Text(
                      '${row['body'] ?? ''}${date == null ? '' : '\n${DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(date.toLocal())}'}',
                    ),
                    isThreeLine: date != null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
