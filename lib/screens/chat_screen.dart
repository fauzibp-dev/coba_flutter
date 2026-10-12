import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/chat_attachment_repository.dart';
import '../services/shop_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  Map<String, dynamic>? _conversation;
  bool _starting = true;
  bool _sending = false;
  Stream<List<Map<String, dynamic>>>? _messages;

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
      setState(() {
        _conversation = conversation;
        // Re-use one subscription across rebuilds and outgoing messages.
        _messages = _messagesStream(conversation['id'] as String);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Stream<List<Map<String, dynamic>>> _messagesStream(String conversationId) {
    return Supabase.instance.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at');
  }

  Future<void> _send() async {
    if (_conversation == null || _controller.text.trim().isEmpty) return;
    final text = _controller.text;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await ShopRepository.instance.sendMessage(_conversation!['id'] as String, text);
    } catch (e) {
      _controller.text = text;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendImage() async {
    if (_conversation == null || _sending) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ChatAttachmentRepository.instance.sendImage(
        _conversation!['id'] as String,
        file,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
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
            Text(
              'Koperasi Merah Putih Kerten',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: _starting
          ? const Center(child: CircularProgressIndicator())
          : _conversation == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.support_agent_rounded, size: 52),
                        const SizedBox(height: 12),
                        const Text('Chat belum dapat dibuka.'),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _start, child: const Text('Coba lagi')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
                      color: const Color(0xFFFFF5F5),
                      child: const Text(
                        'Percakapan tersimpan di akunmu. Jangan kirim password, OTP, PIN, atau data kartu pembayaran.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _messages,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Pesan tidak dapat dimuat: ${friendlyError(snapshot.error!)}', textAlign: TextAlign.center),
                                    const SizedBox(height: 12),
                                    OutlinedButton(
                                      onPressed: () => setState(() {
                                        _messages = _messagesStream(_conversation!['id'] as String);
                                      }),
                                      child: const Text('Coba lagi'),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          final rows = snapshot.data ?? const <Map<String, dynamic>>[];
                          if (rows.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'Tulis pertanyaan atau kirim foto. Tim koperasi dapat membalas percakapan ini dari Customer Support.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: AppTheme.textSecondary),
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(16),
                            itemCount: rows.length,
                            itemBuilder: (_, reverseIndex) {
                              final row = rows[rows.length - 1 - reverseIndex];
                              final mine = row['sender_id'] == ShopRepository.instance.user?.id;
                              return _MessageBubble(row: row, mine: mine);
                            },
                          );
                        },
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: AppTheme.border)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            IconButton(
                              tooltip: 'Kirim gambar',
                              onPressed: _sending ? null : _sendImage,
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                minLines: 1,
                                maxLines: 4,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(hintText: 'Tulis pesan...'),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton.filled(
                              onPressed: _sending ? null : _send,
                              icon: _sending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.send_rounded),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.row, required this.mine});
  final Map<String, dynamic> row;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final type = row['message_type']?.toString() ?? 'text';
    final metadata = row['metadata'];
    final attachmentPath = metadata is Map ? metadata['attachment_path']?.toString() : null;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFFFFE5E5) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (type == 'image' && attachmentPath != null)
              FutureBuilder<String>(
                future: ChatAttachmentRepository.instance.signedUrl(attachmentPath),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                      width: 190,
                      height: 130,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      snap.data!,
                      width: 220,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(
                        width: 190,
                        height: 100,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  );
                },
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Text(row['body']?.toString() ?? ''),
              ),
            if (time != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('dd MMM • HH:mm', 'id_ID').format(time.toLocal()),
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(
                      row['is_read'] == true ? Icons.done_all_rounded : Icons.done_rounded,
                      size: 13,
                      color: row['is_read'] == true ? AppTheme.success : AppTheme.textSecondary,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
