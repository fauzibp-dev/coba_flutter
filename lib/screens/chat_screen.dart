import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  String? _conversationId;
  late Future<List<Map<String, dynamic>>> _future;
  bool _booting = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final id = await ShopRepository.instance.conversationId();
      if (!mounted) return;
      _conversationId = id;
      _future = ShopRepository.instance.messages(id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _booting = false);
    }
  }

  void _reload() {
    final id = _conversationId;
    if (id != null) _future = ShopRepository.instance.messages(id);
  }

  Future<void> _send() async {
    final id = _conversationId;
    final text = _text.text.trim();
    if (id == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ShopRepository.instance.sendMessage(id, text);
      _text.clear();
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _time(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    return DateFormat('dd MMM, HH:mm', 'id_ID').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ShopRepository.instance.user?.id;
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chat Koperasi', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Koperasi Merah Putih Kerten', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(onPressed: _conversationId == null ? null : () => setState(_reload), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _booting
          ? const Center(child: CircularProgressIndicator())
          : _conversationId == null
              ? const Center(child: Text('Chat belum dapat dibuka.'))
              : Column(
                  children: [
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Gagal memuat chat: ${friendlyError(snapshot.error!)}'));
                          }
                          final rows = snapshot.data ?? [];
                          if (rows.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Text('Belum ada pesan. Tulis pertanyaan untuk pengelola koperasi.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                              ),
                            );
                          }
                          return RefreshIndicator(
                            onRefresh: () async {
                              setState(_reload);
                              await _future;
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: rows.length,
                              itemBuilder: (_, index) {
                                final row = rows[index];
                                final mine = row['sender_id'] == currentUser;
                                return Align(
                                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 310),
                                    margin: const EdgeInsets.only(bottom: 9),
                                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                                    decoration: BoxDecoration(
                                      color: mine ? const Color(0xFFFFE5E5) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: mine ? const Color(0xFFFFC7C7) : AppTheme.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(row['body']?.toString() ?? '', style: const TextStyle(height: 1.4)),
                                        const SizedBox(height: 4),
                                        Text(_time(row['created_at']), style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
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
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _text,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(hintText: 'Tulis pesan...'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: Icon(_sending ? Icons.hourglass_top_rounded : Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
