import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatAttachmentRepository {
  ChatAttachmentRepository._();
  static final instance = ChatAttachmentRepository._();
  SupabaseClient get db => Supabase.instance.client;

  Future<void> sendImage(String conversationId, XFile file) async {
    final user = db.auth.currentUser;
    if (user == null) throw StateError('AUTH_REQUIRED');
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) throw StateError('Lampiran chat maksimal 5 MB.');
    final ext = file.path.split('.').last.toLowerCase();
    if (!{'jpg','jpeg','png','webp'}.contains(ext)) throw StateError('Lampiran chat harus JPG, PNG, atau WebP.');
    final path = '${user.id}/$conversationId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await db.storage.from('chat-attachments').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: file.mimeType, upsert: false));
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'message_type': 'image',
      'body': 'Gambar',
      'metadata': {'attachment_path': path, 'file_name': file.name},
    });
  }

  Future<String> signedUrl(String path) => db.storage.from('chat-attachments').createSignedUrl(path, 900);
}
