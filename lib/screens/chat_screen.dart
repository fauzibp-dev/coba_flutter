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
  final _controller = TextEditingController();
  Map<String, dynamic>? _conversation;
  late Future<List<Map<String, dynamic>>> _future;
  bool _starting = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final conversation = await ShopRepository.instance.customerConversation();
      if (!mounted) return;
      _conversation = conversation;
      _future = ShopRepository.instance.messages(conversation['id'] as String);
    } catch (_) {
      if (!mounted) return;
      _future = Future.value([]);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  void _reload() {
    if (_conversation != null) {
      _future = ShopRepository.instance.messages(_conversation!['id'] as String);
    }
  }

  Future<void> _send() async {
    if (_conversation == null || _controller.text.trim().isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await ShopRepository.instance.sendMessage(_conversation!['id'] as String, text);
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pusat Bantuan', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Koperasi Merah Putih Kerten', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : _conversation == null
              ? const Center(child: Text('Chat belum dapat dibuka. Coba lagi nanti.'))
              : Column(
                  children: [
                    Expanded(
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        future: _future,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final rows = snapshot.data ?? [];
                          if (rows.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'Tulis pertanyaanmu. Pengelola koperasi dapat membaca percakapan ini dari backend/admin yang berwenang.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              ),
                            );
                          }
                          return RefreshIndicator(
                            onRefresh: () async {
                              setState(_reload);
                              await _future;
                            },
                            child: ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(16),
                              itemCount: rows.length,
                              itemBuilder: (_, reverseIndex) {
                                final row = rows[rows.length - 1 - reverseIndex];
                                final mine = row['sender_id'] == ShopRepository.instance.user?.id;
                                final time = DateTime.tryParse(row['created_at']?.toString() ?? '');
                                return Align(
                                  alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 310),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
                                    decoration: BoxDecoration(
                                      color: mine ? const Color(0xFFFFE5E5) : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(row['body']?.toString() ?? ''),
                                        ),
                                        if (time != null) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            DateFormat('dd MMM • HH:mm', 'id_ID').format(time.toLocal()),
                                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                          ),
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
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(hintText: 'Tulis pesan...'),
                              ),
                            ),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: const Icon(Icons.send_rounded),
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
