import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CommerceRepository {
  CommerceRepository._();
  static final instance = CommerceRepository._();

  SupabaseClient get db => Supabase.instance.client;
  User? get user => db.auth.currentUser;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Map<String, dynamic>> defaultStore() async {
    final row = await db.from('stores').select().eq('is_active', true).order('created_at').limit(1).single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> storeSettings() async {
    final store = await defaultStore();
    final row = await db.from('store_settings').select().eq('store_id', store['id']).single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> checkoutQuote({
    String? addressId,
    required String shippingMethod,
    String? voucherCode,
  }) async {
    final value = await db.rpc('quote_checkout_v2', params: {
      'p_address_id': addressId,
      'p_shipping_method': shippingMethod,
      'p_voucher_code': voucherCode?.trim().isEmpty == true ? null : voucherCode?.trim(),
    });
    return Map<String, dynamic>.from(value as Map);
  }

  Future<List<Map<String, dynamic>>> advancedSearch({
    String? query,
    String? categoryId,
    num? minPrice,
    num? maxPrice,
    num? minRating,
    String sort = 'relevance',
    int limit = 60,
  }) async {
    final raw = await db.rpc('search_products_v2', params: {
      'p_query': query?.trim(),
      'p_category_id': categoryId,
      'p_min_price': minPrice,
      'p_max_price': maxPrice,
      'p_min_rating': minRating,
      'p_sort': sort,
      'p_limit': limit,
      'p_offset': 0,
    });
    final ids = _maps(raw).map((e) => e['id'].toString()).toList();
    if (ids.isEmpty) return [];
    final full = _maps(await db
        .from('products')
        .select('*, categories(name), product_images(*), product_variants(*), inventory(*)')
        .inFilter('id', ids));
    final byId = {for (final row in full) row['id'].toString(): row};
    final ordered = [for (final id in ids) if (byId[id] != null) byId[id]!];
    if (user != null && query != null && query.trim().isNotEmpty) {
      await db.from('search_history').insert({'user_id': user!.id, 'query': query.trim()});
    }
    return ordered;
  }

  Future<List<String>> recentSearches() async {
    if (user == null) return [];
    final rows = _maps(await db
        .from('search_history')
        .select('query,created_at')
        .eq('user_id', user!.id)
        .order('created_at', ascending: false)
        .limit(30));
    final seen = <String>{};
    final out = <String>[];
    for (final row in rows) {
      final q = row['query']?.toString().trim() ?? '';
      if (q.isNotEmpty && seen.add(q.toLowerCase())) out.add(q);
      if (out.length == 8) break;
    }
    return out;
  }

  Future<void> clearSearchHistory() async {
    if (user == null) return;
    await db.from('search_history').delete().eq('user_id', user!.id);
  }

  Future<void> recordProductView(String productId) async {
    if (user == null) return;
    await db.rpc('record_product_view', params: {'p_product_id': productId});
  }

  Future<List<Map<String, dynamic>>> recentlyViewed() async {
    if (user == null) return [];
    final rows = _maps(await db
        .from('product_views')
        .select('product_id, viewed_at, products(*, product_images(*), inventory(*))')
        .eq('user_id', user!.id)
        .order('viewed_at', ascending: false)
        .limit(30));
    final seen = <String>{};
    final products = <Map<String, dynamic>>[];
    for (final row in rows) {
      final p = row['products'];
      if (p is Map && seen.add(row['product_id'].toString())) {
        products.add(Map<String, dynamic>.from(p));
      }
      if (products.length == 10) break;
    }
    return products;
  }

  Future<List<Map<String, dynamic>>> bestSellers() async {
    final store = await defaultStore();
    return _maps(await db
        .from('products')
        .select('*, categories(name), product_images(*), inventory(*)')
        .eq('store_id', store['id'])
        .eq('status', 'active')
        .order('sold_count', ascending: false)
        .limit(10));
  }

  Future<List<Map<String, dynamic>>> newestProducts() async {
    final store = await defaultStore();
    return _maps(await db
        .from('products')
        .select('*, categories(name), product_images(*), inventory(*)')
        .eq('store_id', store['id'])
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(10));
  }

  Future<List<Map<String, dynamic>>> flashSaleProducts() async {
    final store = await defaultStore();
    final rows = _maps(await db
        .from('campaign_products')
        .select('promo_price,quota,sold_qty,campaigns!inner(id,name,campaign_type,status,starts_at,ends_at,store_id),products(*,product_images(*),inventory(*))')
        .eq('campaigns.store_id', store['id'])
        .eq('campaigns.campaign_type', 'flash_sale')
        .eq('campaigns.status', 'active')
        .limit(20));
    final now = DateTime.now().toUtc();
    final out = <Map<String, dynamic>>[];
    for (final row in rows) {
      final campaign = row['campaigns'];
      final product = row['products'];
      if (campaign is! Map || product is! Map) continue;
      final start = DateTime.tryParse(campaign['starts_at']?.toString() ?? '');
      final end = DateTime.tryParse(campaign['ends_at']?.toString() ?? '');
      if (start != null && start.isAfter(now)) continue;
      if (end != null && end.isBefore(now)) continue;
      final p = Map<String, dynamic>.from(product);
      p['campaign_price'] = row['promo_price'];
      p['campaign_ends_at'] = campaign['ends_at'];
      p['campaign_name'] = campaign['name'];
      p['campaign_quota'] = row['quota'];
      p['campaign_sold_qty'] = row['sold_qty'];
      out.add(p);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> productOptions(String productId) async => _maps(await db
      .from('product_options')
      .select('*, product_option_values(*)')
      .eq('product_id', productId)
      .order('sort_order'));

  Future<List<Map<String, dynamic>>> variantOptionValues(String productId) async => _maps(await db
      .from('variant_option_values')
      .select('variant_id, product_option_values(id,value,option_id,product_options!inner(product_id,name,sort_order))')
      .eq('product_option_values.product_options.product_id', productId));

  Future<Map<String, dynamic>?> shipmentForOrder(String orderId) async {
    final row = await db
        .from('shipments')
        .select('*, shipment_events(*)')
        .eq('order_id', orderId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> paymentProofs(String orderId) async => _maps(await db
      .from('manual_payment_proofs')
      .select()
      .eq('order_id', orderId)
      .order('created_at', ascending: false));

  Future<String> uploadPaymentProof({
    required String orderId,
    required XFile file,
    String? bankName,
    String? payerName,
    num? amount,
  }) async {
    if (user == null) throw StateError('AUTH_REQUIRED');
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) throw StateError('Bukti pembayaran maksimal 5 MB.');
    final ext = file.path.split('.').last.toLowerCase();
    final safeExt = {'jpg', 'jpeg', 'png', 'webp', 'pdf'}.contains(ext) ? ext : 'jpg';
    final path = '${user!.id}/$orderId/${DateTime.now().microsecondsSinceEpoch}.$safeExt';
    await db.storage.from('payment-proofs').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: file.mimeType, upsert: false),
        );
    final result = await db.rpc('submit_manual_payment_proof', params: {
      'p_order_id': orderId,
      'p_proof_path': path,
      'p_bank_name': bankName?.trim(),
      'p_payer_name': payerName?.trim(),
      'p_amount': amount,
    });
    return result as String;
  }

  Future<String> signedPaymentProofUrl(String path) =>
      db.storage.from('payment-proofs').createSignedUrl(path, 900);

  Future<String> requestReturn({
    required String orderId,
    required String reason,
    String? description,
    required String resolution,
    required List<Map<String, dynamic>> items,
  }) async {
    final value = await db.rpc('request_return_v2', params: {
      'p_order_id': orderId,
      'p_reason': reason.trim(),
      'p_description': description?.trim(),
      'p_resolution': resolution,
      'p_items': items,
    });
    return value as String;
  }

  Future<String> uploadReturnEvidence({required String returnId, required XFile file}) async {
    if (user == null) throw StateError('AUTH_REQUIRED');
    final bytes = await file.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) throw StateError('Bukti retur maksimal 8 MB.');
    final ext = file.path.split('.').last.toLowerCase();
    final path = '${user!.id}/$returnId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await db.storage.from('return-evidence').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: file.mimeType));
    final row = await db.from('return_evidence').insert({
      'return_id': returnId,
      'uploaded_by': user!.id,
      'file_path': path,
      'media_type': file.mimeType?.startsWith('video/') == true ? 'video' : 'image',
    }).select('id').single();
    return row['id'] as String;
  }

  Future<String> uploadReviewImage({required String reviewId, required XFile file}) async {
    if (user == null) throw StateError('AUTH_REQUIRED');
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) throw StateError('Foto ulasan maksimal 5 MB.');
    final ext = file.path.split('.').last.toLowerCase();
    final path = '${user!.id}/$reviewId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    await db.storage.from('review-images').uploadBinary(path, bytes, fileOptions: FileOptions(contentType: file.mimeType));
    final url = db.storage.from('review-images').getPublicUrl(path);
    await db.from('review_images').insert({'review_id': reviewId, 'image_url': url});
    return url;
  }

  Future<Map<String, dynamic>> notificationPreferences() async {
    if (user == null) throw StateError('AUTH_REQUIRED');
    final row = await db.from('notification_preferences').select().eq('user_id', user!.id).maybeSingle();
    if (row != null) return Map<String, dynamic>.from(row);
    final created = await db.from('notification_preferences').insert({'user_id': user!.id}).select().single();
    return Map<String, dynamic>.from(created);
  }

  Future<void> updateNotificationPreferences(Map<String, bool> values) async {
    if (user == null) throw StateError('AUTH_REQUIRED');
    await db.from('notification_preferences').upsert({'user_id': user!.id, ...values, 'updated_at': DateTime.now().toUtc().toIso8601String()});
  }

  Future<void> sendPasswordReset(String email) => db.auth.resetPasswordForEmail(email.trim());

  Future<void> updatePassword(String password) => db.auth.updateUser(UserAttributes(password: password));

  Future<void> updateEmail(String email) => db.auth.updateUser(UserAttributes(email: email.trim()));

  Future<void> requestAccountDeletion({String? reason}) async {
    if (user == null) throw StateError('AUTH_REQUIRED');
    await db.from('account_deletion_requests').insert({'user_id': user!.id, 'reason': reason?.trim()});
  }

  Future<Map<String, dynamic>> publicAppSettings() async {
    final rows = _maps(await db.from('app_settings').select().eq('is_public', true));
    return {for (final row in rows) row['key'].toString(): row['value']};
  }
}
