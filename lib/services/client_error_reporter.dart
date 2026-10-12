import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Best-effort reports. No request bodies, form fields, or auth headers.
class ClientErrorReporter {
  ClientErrorReporter._();
  static final instance = ClientErrorReporter._();
  final List<Map<String, String>> pending = [];
  bool busy = false;
  DateTime? previousAt;
  String previous = '';

  String safe(String text, int limit) {
    var result = text.replaceAll(RegExp(r'https?://[^\s]+'), '[url]');
    result = result.replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}'), '[email]');
    result = result.replaceAll(RegExp(r'/Users/[^/\s]+'), '/Users/[user]');
    result = result.replaceAll(RegExp(r'[A-Za-z0-9_-]{40,}'), '[private-value]');
    result = result.replaceAll(RegExp(r'\b\d{13,19}\b'), '[number]');
    return result.length > limit ? result.substring(0, limit) : result;
  }

  void record(Object problem, {StackTrace? trace, String source = 'handled', String screen = ''}) {
    final message = safe(problem.toString(), 1200);
    final now = DateTime.now();
    if (previous == message && previousAt != null &&
        now.difference(previousAt!).inSeconds < 15) return;
    previous = message;
    previousAt = now;
    if (pending.length >= 30) pending.removeAt(0);
    pending.add({
      'p_source': safe(source, 80),
      'p_message': message,
      'p_stack': safe(trace?.toString() ?? '', 5000),
      'p_screen': safe(screen, 120),
      'p_severity': source == 'platform_uncaught' ? 'fatal' : 'error',
      'p_app_version': '1.5.4',
      'p_platform': defaultTargetPlatform.name,
    });
    unawaited(flush());
  }

  Future<void> flush() async {
    if (busy || pending.isEmpty) return;
    SupabaseClient db;
    try {
      db = Supabase.instance.client;
      if (db.auth.currentUser == null) return;
    } catch (_) { return; }
    busy = true;
    try {
      while (pending.isNotEmpty && db.auth.currentUser != null) {
        try {
          await db.rpc('capture_client_error', params: pending.first)
              .timeout(const Duration(seconds: 5));
          pending.removeAt(0);
        } catch (_) { break; }
      }
    } finally { busy = false; }
  }
}
