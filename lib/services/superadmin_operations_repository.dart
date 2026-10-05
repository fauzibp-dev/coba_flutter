import 'package:supabase_flutter/supabase_flutter.dart';

class SuperadminOperationsRepository {
  SuperadminOperationsRepository._();
  static final instance = SuperadminOperationsRepository._();

  SupabaseClient get db => Supabase.instance.client;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<List<Map<String, dynamic>>> conversations({String? storeId}) async =>
      _maps(await db.rpc('superadmin_list_conversations', params: {'p_store_id': storeId}));

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final data = await db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return _maps(data);
  }

  Future<void> markConversationRead(String conversationId) =>
      db.rpc('superadmin_mark_conversation_read', params: {'p_conversation_id': conversationId});

  Future<void> sendMessage(String conversationId, String body) async {
    final text = body.trim();
    final user = db.auth.currentUser;
    if (user == null) throw StateError('AUTH_REQUIRED');
    if (text.isEmpty) return;
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'message_type': 'text',
      'body': text,
    });
  }

  Future<int> sendNotification({
    String? userId,
    String? storeId,
    required String title,
    required String body,
    String type = 'announcement',
  }) async {
    final value = await db.rpc('superadmin_send_notification', params: {
      'p_user_id': userId,
      'p_store_id': storeId,
      'p_title': title.trim(),
      'p_body': body.trim(),
      'p_type': type,
    });
    return (value as num).toInt();
  }

  Future<List<Map<String, dynamic>>> integrations({String? storeId}) async =>
      _maps(await db.rpc('superadmin_list_integrations', params: {'p_store_id': storeId}));

  Future<String> saveIntegration({
    String? id,
    required String storeId,
    required String name,
    required String sourceType,
    String? baseUrl,
    required bool isActive,
  }) async {
    final value = await db.rpc('superadmin_save_integration', params: {
      'p_source_id': id,
      'p_store_id': storeId,
      'p_name': name.trim(),
      'p_source_type': sourceType.trim(),
      'p_base_url': baseUrl?.trim(),
      'p_is_active': isActive,
    });
    return value as String;
  }

  Future<List<Map<String, dynamic>>> syncLogs({String? sourceId, int limit = 200}) async =>
      _maps(await db.rpc('superadmin_list_sync_logs', params: {
        'p_source_id': sourceId,
        'p_limit': limit,
      }));
}
