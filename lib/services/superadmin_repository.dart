import 'package:supabase_flutter/supabase_flutter.dart';

class SuperadminRepository {
  SuperadminRepository._();
  static final instance = SuperadminRepository._();

  SupabaseClient get db => Supabase.instance.client;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<bool> isSuperAdmin() async {
    if (db.auth.currentUser == null) return false;
    final value = await db.rpc('is_platform_super_admin');
    return value == true;
  }

  Future<Map<String, dynamic>> dashboard() async {
    final value = await db.rpc('superadmin_dashboard');
    return Map<String, dynamic>.from(value as Map);
  }

  Future<List<Map<String, dynamic>>> stores() async =>
      _maps(await db.rpc('superadmin_list_stores'));

  Future<String> saveStore({
    String? id,
    required String name,
    required String slug,
    String? description,
    String? address,
    String? phone,
    required bool isActive,
  }) async {
    final value = await db.rpc('superadmin_save_store', params: {
      'p_store_id': id,
      'p_name': name.trim(),
      'p_slug': slug.trim(),
      'p_description': description?.trim(),
      'p_address': address?.trim(),
      'p_phone': phone?.trim(),
      'p_is_active': isActive,
    });
    return value as String;
  }

  Future<List<Map<String, dynamic>>> users({String? search}) async =>
      _maps(await db.rpc('superadmin_list_users', params: {'p_search': search?.trim()}));

  Future<void> setStoreMember({
    required String userId,
    required String storeId,
    required String role,
    required bool enabled,
  }) async {
    await db.rpc('superadmin_set_store_member', params: {
      'p_user_id': userId,
      'p_store_id': storeId,
      'p_role': role,
      'p_enabled': enabled,
    });
  }

  Future<void> setPlatformAdmin({required String userId, required bool enabled}) async {
    await db.rpc('superadmin_set_platform_admin', params: {
      'p_user_id': userId,
      'p_enabled': enabled,
    });
  }

  Future<List<Map<String, dynamic>>> products({String? storeId, String? search}) async =>
      _maps(await db.rpc('superadmin_list_products', params: {
        'p_store_id': storeId,
        'p_search': search?.trim(),
      }));

  Future<Map<String, dynamic>> productDetail(String productId) async {
    final row = await db
        .from('products')
        .select('*, categories(name), inventory(*)')
        .eq('id', productId)
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> categories(String storeId) async {
    final data = await db
        .from('categories')
        .select()
        .eq('store_id', storeId)
        .order('sort_order');
    return _maps(data);
  }

  Future<String> saveProduct({
    String? id,
    required String storeId,
    required String name,
    required String description,
    required num price,
    num? compareAtPrice,
    String? categoryId,
    required String sku,
    required int stock,
    required String status,
    required bool featured,
    String? stockReason,
  }) async {
    final value = await db.rpc('superadmin_save_product', params: {
      'p_product_id': id,
      'p_store_id': storeId,
      'p_name': name.trim(),
      'p_description': description.trim(),
      'p_price': price,
      'p_compare_at_price': compareAtPrice,
      'p_category_id': categoryId,
      'p_sku': sku.trim(),
      'p_stock': stock,
      'p_status': status,
      'p_featured': featured,
      'p_stock_reason': stockReason?.trim(),
    });
    return value as String;
  }

  Future<List<Map<String, dynamic>>> orders({String? storeId, String? status}) async =>
      _maps(await db.rpc('superadmin_list_orders', params: {
        'p_store_id': storeId,
        'p_status': status,
      }));

  Future<void> updateOrderStatus(String orderId, String status, {String? note}) async {
    await db.rpc('admin_update_order_status', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_note': note,
    });
  }

  Future<List<Map<String, dynamic>>> vouchers({String? storeId}) async =>
      _maps(await db.rpc('superadmin_list_vouchers', params: {'p_store_id': storeId}));

  Future<String> saveVoucher({
    String? id,
    required String storeId,
    required String code,
    required String title,
    required String discountType,
    required num discountValue,
    num minimumPurchase = 0,
    num? maximumDiscount,
    int? usageLimit,
    int usagePerUser = 1,
    DateTime? startsAt,
    DateTime? endsAt,
    required bool isActive,
  }) async {
    final value = await db.rpc('superadmin_save_voucher', params: {
      'p_voucher_id': id,
      'p_store_id': storeId,
      'p_code': code.trim(),
      'p_title': title.trim(),
      'p_discount_type': discountType,
      'p_discount_value': discountValue,
      'p_minimum_purchase': minimumPurchase,
      'p_maximum_discount': maximumDiscount,
      'p_usage_limit': usageLimit,
      'p_usage_per_user': usagePerUser,
      'p_starts_at': (startsAt ?? DateTime.now()).toUtc().toIso8601String(),
      'p_ends_at': endsAt?.toUtc().toIso8601String(),
      'p_is_active': isActive,
    });
    return value as String;
  }

  Future<List<Map<String, dynamic>>> banners({String? storeId}) async =>
      _maps(await db.rpc('superadmin_list_banners', params: {'p_store_id': storeId}));

  Future<String> saveBanner({
    String? id,
    required String storeId,
    required String title,
    String? subtitle,
    String? imageUrl,
    String? targetType,
    String? targetId,
    int sortOrder = 0,
    DateTime? startsAt,
    DateTime? endsAt,
    required bool isActive,
  }) async {
    final value = await db.rpc('superadmin_save_banner', params: {
      'p_banner_id': id,
      'p_store_id': storeId,
      'p_title': title.trim(),
      'p_subtitle': subtitle?.trim(),
      'p_image_url': imageUrl?.trim(),
      'p_target_type': targetType?.trim(),
      'p_target_id': targetId,
      'p_sort_order': sortOrder,
      'p_starts_at': (startsAt ?? DateTime.now()).toUtc().toIso8601String(),
      'p_ends_at': endsAt?.toUtc().toIso8601String(),
      'p_is_active': isActive,
    });
    return value as String;
  }

  Future<List<Map<String, dynamic>>> returns({String? storeId}) async =>
      _maps(await db.rpc('superadmin_list_returns', params: {'p_store_id': storeId}));

  Future<void> updateReturnStatus(String returnId, String status, {String? note}) async {
    await db.rpc('superadmin_update_return_status', params: {
      'p_return_id': returnId,
      'p_status': status,
      'p_note': note,
    });
  }

  Future<List<Map<String, dynamic>>> auditLogs({int limit = 200}) async =>
      _maps(await db.rpc('superadmin_audit_logs', params: {'p_limit': limit}));
}
