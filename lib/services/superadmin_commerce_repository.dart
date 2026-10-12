import 'package:supabase_flutter/supabase_flutter.dart';

class SuperadminCommerceRepository {
  SuperadminCommerceRepository._();
  static final instance = SuperadminCommerceRepository._();
  SupabaseClient get db => Supabase.instance.client;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Map<String, dynamic>> analytics({int days = 30}) async {
    final value = await db.rpc('superadmin_commerce_analytics', params: {'p_days': days});
    return Map<String, dynamic>.from(value as Map);
  }

  Future<List<Map<String, dynamic>>> campaigns({String? storeId}) async {
    dynamic query = db.from('campaigns').select('*, stores(name), campaign_products(*, products(name,sku,price), product_variants(name,sku))');
    if (storeId != null) query = query.eq('store_id', storeId);
    return _maps(await query.order('created_at', ascending: false));
  }

  Future<String> saveCampaign({
    String? id,
    required String storeId,
    required String name,
    required String type,
    required String status,
    required DateTime startsAt,
    DateTime? endsAt,
    int priority = 0,
  }) async {
    final data = {
      'store_id': storeId,
      'name': name.trim(),
      'campaign_type': type,
      'status': status,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt?.toUtc().toIso8601String(),
      'priority': priority,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      final row = await db.from('campaigns').insert(data).select('id').single();
      return row['id'] as String;
    }
    await db.from('campaigns').update(data).eq('id', id);
    return id;
  }

  Future<List<Map<String, dynamic>>> storeProducts(String storeId) async => _maps(await db
      .from('products')
      .select('id,name,sku,price,status,product_variants(id,name,sku,price_override,is_active)')
      .eq('store_id', storeId)
      .order('name'));

  Future<void> upsertCampaignProduct({
    required String campaignId,
    required String productId,
    String? variantId,
    required num promoPrice,
    int? quota,
    int? perUserLimit,
  }) async {
    final existing = await db
        .from('campaign_products')
        .select('campaign_id')
        .eq('campaign_id', campaignId)
        .eq('product_id', productId)
        .filter('variant_id', variantId == null ? 'is' : 'eq', variantId)
        .maybeSingle();
    final data = {
      'campaign_id': campaignId,
      'product_id': productId,
      'variant_id': variantId,
      'promo_price': promoPrice,
      'quota': quota,
      'per_user_limit': perUserLimit,
    };
    if (existing == null) {
      await db.from('campaign_products').insert(data);
    } else {
      dynamic update = db.from('campaign_products').update(data).eq('campaign_id', campaignId).eq('product_id', productId);
      update = variantId == null ? update.isFilter('variant_id', null) : update.eq('variant_id', variantId);
      await update;
    }
  }

  Future<void> removeCampaignProduct({required String campaignId, required String productId, String? variantId}) async {
    dynamic q = db.from('campaign_products').delete().eq('campaign_id', campaignId).eq('product_id', productId);
    q = variantId == null ? q.isFilter('variant_id', null) : q.eq('variant_id', variantId);
    await q;
  }

  Future<List<Map<String, dynamic>>> accountDeletionRequests() async {
    // No direct foreign key exists between account_deletion_requests and profiles.
    // Use a platform-admin-checked RPC instead of invalid PostgREST embedding.
    final value = await db.rpc('superadmin_privacy_queue');
    return _maps(value);
  }

  Future<void> updateAppSetting(String key, Map<String, dynamic> value, {bool isPublic = true}) async {
    await db.from('app_settings').upsert({
      'key': key,
      'value': value,
      'is_public': isPublic,
      'updated_by': db.auth.currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
