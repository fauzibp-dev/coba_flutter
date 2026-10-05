import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
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

  String _time(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(date);
  }

  Future<void> _read(Map<String, dynamic> row) async {
    if (row['is_read'] == true) return;
    try {
      await ShopRepository.instance.markNotificationRead(row['id'] as String);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat notifikasi: ${friendlyError(snapshot.error!)}'));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_none_rounded, size: 56, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text('Belum ada notifikasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    SizedBox(height: 5),
                    Text('Update pesanan dan retur akan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
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
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (_, index) {
                final row = rows[index];
                final unread = row['is_read'] != true;
                return InkWell(
                  onTap: () => _read(row),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: unread ? const Color(0xFFFFF4F4) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: unread ? const Color(0xFFFFCCCC) : AppTheme.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(unread ? Icons.notifications_active_outlined : Icons.notifications_none_rounded, color: unread ? AppTheme.primary : AppTheme.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['title']?.toString() ?? 'Notifikasi', style: TextStyle(fontWeight: unread ? FontWeight.w900 : FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(row['body']?.toString() ?? '', style: const TextStyle(height: 1.4)),
                              const SizedBox(height: 7),
                              Text(_time(row['created_at']), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          ),
                        ),
                      ],
                    ),
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
