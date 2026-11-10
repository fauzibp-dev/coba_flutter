import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_operations_repository.dart';
import '../../services/superadmin_repository.dart';

class SuperadminSupportScreen extends StatefulWidget {
  const SuperadminSupportScreen({super.key});

  @override
  State<SuperadminSupportScreen> createState() => _SuperadminSupportScreenState();
}

class _SuperadminSupportScreenState extends State<SuperadminSupportScreen> {
  String? _storeId;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Future.wait([
      SuperadminOperationsRepository.instance.conversations(storeId: _storeId),
      SuperadminRepository.instance.stores(),
    ]);
  }

  Future<void> _open(Map<String, dynamic> conversation) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _SupportThreadScreen(conversation: conversation)),
    );
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Support Inbox', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat chat: ${friendlyError(snapshot.error!)}'));
          final conversations = snapshot.data![0] as List<Map<String, dynamic>>;
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
                child: conversations.isEmpty
                    ? const Center(child: Text('Belum ada percakapan pelanggan.'))
                    : RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: conversations.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = conversations[i];
                            final unread = (c['unread_count'] as num?)?.toInt() ?? 0;
                            final time = DateTime.tryParse(c['last_message_at']?.toString() ?? c['updated_at']?.toString() ?? '');
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(color: unread > 0 ? const Color(0xFFFFBABA) : AppTheme.border),
                              ),
                              child: ListTile(
                                onTap: () => _open(c),
                                leading: CircleAvatar(
                                  backgroundColor: unread > 0 ? const Color(0xFFFFE5E5) : const Color(0xFFF2F2F2),
                                  child: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.primary),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c['customer_name']?.toString().isNotEmpty == true ? c['customer_name'].toString() : c['customer_email']?.toString() ?? 'Pelanggan',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w700),
                                      ),
                                    ),
                                    if (unread > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(20)),
                                        child: Text('$unread', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${c['store_name']}\n${c['last_message'] ?? 'Belum ada pesan'}${time == null ? '' : ' • ${DateFormat('dd MMM HH:mm', 'id_ID').format(time.toLocal())}'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                isThreeLine: true,
                                trailing: const Icon(Icons.chevron_right_rounded),
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

class _SupportThreadScreen extends StatefulWidget {
  const _SupportThreadScreen({required this.conversation});
  final Map<String, dynamic> conversation;

  @override
  State<_SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<_SupportThreadScreen> {
  final _controller = TextEditingController();
  late Future<List<Map<String, dynamic>>> _future;
  bool _sending = false;

  String get _conversationId => widget.conversation['id'].toString();

  @override
  void initState() {
    super.initState();
    _reload();
    SuperadminOperationsRepository.instance.markConversationRead(_conversationId).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reload() => _future = SuperadminOperationsRepository.instance.messages(_conversationId);

  Future<void> _send() async {
    if (_sending || _controller.text.trim().isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await SuperadminOperationsRepository.instance.sendMessage(_conversationId, text);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerId = widget.conversation['customer_id']?.toString();
    final customer = widget.conversation['customer_name']?.toString().isNotEmpty == true
        ? widget.conversation['customer_name'].toString()
        : widget.conversation['customer_email']?.toString() ?? 'Pelanggan';
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(widget.conversation['store_name']?.toString() ?? 'KKMP Kerten', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Gagal memuat pesan: ${friendlyError(snapshot.error!)}'));
                final rows = snapshot.data ?? [];
                if (rows.isEmpty) return const Center(child: Text('Belum ada pesan.'));
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _future;
                    await SuperadminOperationsRepository.instance.markConversationRead(_conversationId);
                  },
                  child: ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: rows.length,
                    itemBuilder: (_, reverseIndex) {
                      final row = rows[rows.length - 1 - reverseIndex];
                      final fromCustomer = row['sender_id']?.toString() == customerId;
                      final time = DateTime.tryParse(row['created_at']?.toString() ?? '');
                      return Align(
                        alignment: fromCustomer ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 310),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                          decoration: BoxDecoration(
                            color: fromCustomer ? Colors.white : const Color(0xFFFFE5E5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Align(alignment: Alignment.centerLeft, child: Text(row['body']?.toString() ?? '')),
                              if (time != null) ...[
                                const SizedBox(height: 3),
                                Text(DateFormat('dd MMM • HH:mm', 'id_ID').format(time.toLocal()), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _controller, minLines: 1, maxLines: 4, decoration: const InputDecoration(hintText: 'Balas sebagai KKMP Kerten...'))),
                  IconButton.filled(onPressed: _sending ? null : _send, icon: const Icon(Icons.send_rounded)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
