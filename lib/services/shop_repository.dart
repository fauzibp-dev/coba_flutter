import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils/app_utils.dart';

class ShopRepository {
  ShopRepository._();
  static final instance = ShopRepository._();

  SupabaseClient get db => Supabase.instance.client;
  User? get user => db.auth.currentUser;
  bool get isSignedIn => user != null;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Map<String, dynamic>> store() async {
    final data = await db
        .from('stores')
        .select()
        .eq('is_active', true)
        .order('created_at')
        .limit(1)
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final shop = await store();
    final data = await db
        .from('categories')
        .select()
        .eq('store_id', shop['id'])
        .eq('is_active', true)
        .order('sort_order');
    return _maps(data);
  }

  Future<List<Map<String, dynamic>>> banners() async {
    final shop = await store();
    final data = await db
        .from('banners')
        .select()
        .eq('store_id', shop['id'])
        .eq('is_active', true)
        .lte('starts_at', DateTime.now().toUtc().toIso8601String())
        .order('sort_order');
    return _maps(data).where((row) {
      final end = DateTime.tryParse(row['ends_at']?.toString() ?? '');
      return end == null || end.isAfter(DateTime.now().toUtc());
    }).toList();
  }

  Future<List<Map<String, dynamic>>> products({
    String? search,
    String? categoryId,
    bool featuredOnly = false,
  }) async {
    final shop = await store();
    dynamic query = db.from('products').select(
          '*, categories(name), product_images(*), product_variants(*), inventory(*)',
        );
    query = query.eq('store_id', shop['id']).eq('status', 'active');
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (featuredOnly) query = query.eq('is_featured', true);
    if (search != null && search.trim().isNotEmpty) {
      final safe = search.trim().replaceAll(',', ' ');
      query = query.or('name.ilike.%$safe%,description.ilike.%$safe%');
    }
    final data = await query.order('created_at', ascending: false).limit(60);
    return _maps(data);
  }

  Future<Map<String, dynamic>> product(String id) async {
    final data = await db
        .from('products')
        .select(
          '*, categories(name), product_images(*), product_variants(*), inventory(*), reviews(id,rating,comment,seller_reply,created_at,review_images(*),review_helpful_votes(user_id))',
        )
        .eq('id', id)
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> signIn(String email, String password) async {
    await db.auth.signInWithPassword(email: email.trim(), password: password);
  }

  Future<bool> signUp(String name, String email, String password) async {
    final response = await db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': name.trim()},
    );
    return response.session != null;
  }

  Future<void> signOut() => db.auth.signOut();

  Future<Map<String, dynamic>?> membership() async {
    if (!isSignedIn) return null;
    final data = await db
        .from('store_members')
        .select('id, store_id, role')
        .eq('user_id', user!.id)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  Future<bool> isStaff() async => (await membership()) != null;

  Future<Map<String, dynamic>?> profile() async {
    if (!isSignedIn) return null;
    final data = await db.from('profiles').select().eq('id', user!.id).maybeSingle();
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  Future<void> updateProfile({required String name, String? phone}) async {
    await db.from('profiles').update({
      'full_name': name.trim(),
      'phone': phone?.trim(),
    }).eq('id', user!.id);
  }

  Future<void> addToCart(String productId, {String? variantId, int quantity = 1}) async {
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    await db.rpc('add_to_cart', params: {
      'p_product_id': productId,
      'p_variant_id': variantId,
      'p_quantity': quantity,
    });
  }

  Future<List<Map<String, dynamic>>> cartItems() async {
    if (!isSignedIn) return [];
    final cart = await db.from('carts').select('id').eq('user_id', user!.id).maybeSingle();
    if (cart == null) return [];
    final data = await db
        .from('cart_items')
        .select('*, products(*, product_images(*)), product_variants(*)')
        .eq('cart_id', cart['id'])
        .order('created_at');
    return _maps(data);
  }

  Future<void> setCartQuantity(String itemId, int quantity) async {
    await db.rpc('set_cart_quantity', params: {
      'p_item_id': itemId,
      'p_quantity': quantity.clamp(0, 99),
    });
  }

  Future<void> removeCartItem(String itemId) => setCartQuantity(itemId, 0);

  Future<List<Map<String, dynamic>>> addresses() async {
    if (!isSignedIn) return [];
    final data = await db
        .from('addresses')
        .select()
        .eq('user_id', user!.id)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<String> addAddress({
    required String label,
    required String recipientName,
    required String phone,
    required String province,
    required String city,
    required String district,
    required String addressLine,
    String? postalCode,
    String? notes,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      await db.from('addresses').update({'is_default': false}).eq('user_id', user!.id);
    }
    final row = await db.from('addresses').insert({
      'user_id': user!.id,
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'province': province,
      'city': city,
      'district': district,
      'address_line': addressLine,
      'postal_code': postalCode,
      'notes': notes,
      'is_default': isDefault,
    }).select('id').single();
    return row['id'] as String;
  }

  Future<void> updateAddress({
    required String id,
    required String label,
    required String recipientName,
    required String phone,
    required String province,
    required String city,
    required String district,
    required String addressLine,
    String? postalCode,
    String? notes,
    bool isDefault = false,
  }) async {
    if (isDefault) {
      await db.from('addresses').update({'is_default': false}).eq('user_id', user!.id);
    }
    await db.from('addresses').update({
      'label': label,
      'recipient_name': recipientName,
      'phone': phone,
      'province': province,
      'city': city,
      'district': district,
      'address_line': addressLine,
      'postal_code': postalCode,
      'notes': notes,
      'is_default': isDefault,
    }).eq('id', id).eq('user_id', user!.id);
  }

  Future<void> deleteAddress(String id) =>
      db.from('addresses').delete().eq('id', id).eq('user_id', user!.id);

  Future<String> checkout({
    String? addressId,
    required String paymentMethod,
    required String shippingMethod,
    required String clientRequestId,
    String? voucherCode,
    String? notes,
  }) async {
    final result = await db.rpc('create_checkout_v2', params: {
      'p_address_id': addressId,
      'p_payment_method': paymentMethod,
      'p_shipping_method': shippingMethod,
      'p_voucher_code': voucherCode?.trim().isEmpty == true ? null : voucherCode?.trim(),
      'p_notes': notes?.trim(),
      'p_client_request_id': clientRequestId,
    });
    return result as String;
  }

  Future<List<Map<String, dynamic>>> myOrders() async {
    if (!isSignedIn) return [];
    final data = await db
        .from('orders')
        .select('*, order_items(*), shipments(status,tracking_number,internal_delivery_code,estimated_delivery_at)')
        .eq('user_id', user!.id)
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<Map<String, dynamic>> orderDetail(String orderId) async {
    final data = await db
        .from('orders')
        .select('*, order_items(*), order_status_history(*), payments(*), shipments(*, shipment_events(*)), manual_payment_proofs(*), returns(*, return_items(*), return_evidence(*))')
        .eq('id', orderId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await db.rpc('cancel_my_order', params: {
      'p_order_id': orderId,
      'p_reason': reason,
    });
  }

  Future<Map<String, dynamic>?> reviewForOrderItem(String orderItemId) async {
    if (!isSignedIn) return null;
    final row = await db
        .from('reviews')
        .select('*, review_images(*)')
        .eq('order_item_id', orderItemId)
        .eq('user_id', user!.id)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<String> submitReview({
    required String orderItemId,
    required String productId,
    required int rating,
    String? comment,
  }) async {
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    final row = await db.from('reviews').insert({
      'user_id': user!.id,
      'product_id': productId,
      'order_item_id': orderItemId,
      'rating': rating,
      'comment': comment?.trim().isEmpty == true ? null : comment?.trim(),
    }).select('id').single();
    return row['id'] as String;
  }

  Future<void> toggleHelpfulReview(String reviewId) async {
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    final existing = await db
        .from('review_helpful_votes')
        .select('review_id')
        .eq('review_id', reviewId)
        .eq('user_id', user!.id)
        .maybeSingle();
    if (existing == null) {
      await db.from('review_helpful_votes').insert({'review_id': reviewId, 'user_id': user!.id});
    } else {
      await db.from('review_helpful_votes').delete().eq('review_id', reviewId).eq('user_id', user!.id);
    }
  }

  Future<List<Map<String, dynamic>>> notifications() async {
    if (!isSignedIn) return [];
    final data = await db
        .from('notifications')
        .select()
        .eq('user_id', user!.id)
        .order('created_at', ascending: false)
        .limit(100);
    return _maps(data);
  }

  Future<void> markNotificationRead(String id) => db
      .from('notifications')
      .update({'is_read': true})
      .eq('id', id)
      .eq('user_id', user!.id);

  Future<void> markAllNotificationsRead() async {
    if (!isSignedIn) return;
    await db.from('notifications').update({'is_read': true}).eq('user_id', user!.id).eq('is_read', false);
  }

  Future<Map<String, dynamic>> customerConversation() async {
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    final shop = await store();
    final existing = await db
        .from('conversations')
        .select()
        .eq('store_id', shop['id'])
        .eq('customer_id', user!.id)
        .maybeSingle();
    if (existing != null) return Map<String, dynamic>.from(existing);
    final row = await db.from('conversations').insert({
      'store_id': shop['id'],
      'customer_id': user!.id,
    }).select().single();
    return Map<String, dynamic>.from(row);
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final data = await db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return _maps(data);
  }

  Future<void> sendMessage(String conversationId, String body, {String? replyToId}) async {
    final text = body.trim();
    if (text.isEmpty) return;
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user!.id,
      'message_type': 'text',
      'body': text,
      'reply_to_id': replyToId,
    });
    // The database's AFTER INSERT trigger updates conversation timestamps.
    // A second client UPDATE is blocked by RLS and caused a false send error.
  }

  Future<void> requestReturn({
    required String orderId,
    required String reason,
    String? description,
  }) async {
    await db.from('returns').insert({
      'order_id': orderId,
      'user_id': user!.id,
      'reason': reason.trim(),
      'description': description?.trim(),
    });
  }

  Future<bool> isWishlisted(String productId) async {
    if (!isSignedIn) return false;
    final data = await db
        .from('wishlists')
        .select('id')
        .eq('user_id', user!.id)
        .eq('product_id', productId)
        .maybeSingle();
    return data != null;
  }

  Future<bool> toggleWishlist(String productId) async {
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    final existing = await db
        .from('wishlists')
        .select('id')
        .eq('user_id', user!.id)
        .eq('product_id', productId)
        .maybeSingle();
    if (existing == null) {
      await db.from('wishlists').insert({'user_id': user!.id, 'product_id': productId});
      return true;
    }
    await db.from('wishlists').delete().eq('id', existing['id']);
    return false;
  }

  Future<List<Map<String, dynamic>>> wishlistProducts() async {
    if (!isSignedIn) return [];
    final data = await db
        .from('wishlists')
        .select('id, products(*, product_images(*), inventory(*))')
        .eq('user_id', user!.id)
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<List<Map<String, dynamic>>> adminProducts() async {
    final member = await membership();
    if (member == null) return [];
    final data = await db
        .from('products')
        .select('*, categories(name), product_images(*), product_variants(*), inventory(*)')
        .eq('store_id', member['store_id'])
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<List<Map<String, dynamic>>> adminCategories() async {
    final member = await membership();
    if (member == null) return [];
    final data = await db
        .from('categories')
        .select()
        .eq('store_id', member['store_id'])
        .order('sort_order');
    return _maps(data);
  }

  Future<String> saveProduct({
    String? productId,
    required String name,
    required String description,
    required num price,
    num? compareAtPrice,
    required String categoryId,
    required String sku,
    required int stock,
    required bool active,
    required bool featured,
    String? stockReason,
    XFile? image,
  }) async {
    final member = await membership();
    if (member == null) throw StateError('Not authorized');
    final storeId = member['store_id'] as String;
    final slug = '${slugify(name)}-${DateTime.now().millisecondsSinceEpoch}';
    final result = await db.rpc('save_product_core', params: {
      'p_product_id': productId,
      'p_name': name.trim(),
      'p_slug': slug,
      'p_description': description.trim(),
      'p_price': price,
      'p_compare_at_price': compareAtPrice,
      'p_category_id': categoryId,
      'p_sku': sku.trim(),
      'p_stock': stock,
      'p_active': active,
      'p_featured': featured,
      'p_stock_reason': stockReason?.trim(),
    });
    final id = result as String;
    if (image != null) {
      final bytes = await image.readAsBytes();
      final ext = image.path.split('.').last.toLowerCase();
      final path = '$storeId/$id/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await db.storage.from('product-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: image.mimeType, upsert: false),
          );
      final url = db.storage.from('product-images').getPublicUrl(path);
      await db.from('product_images').update({'is_primary': false}).eq('product_id', id);
      await db.from('product_images').insert({
        'product_id': id,
        'image_url': url,
        'is_primary': true,
        'sort_order': 0,
      });
    }
    return id;
  }

  Future<void> archiveProduct(String id) => db.rpc('archive_product', params: {'p_product_id': id});

  Future<List<Map<String, dynamic>>> adminOrders() async {
    final member = await membership();
    if (member == null) return [];
    final data = await db
        .from('orders')
        .select('*, order_items(*), profiles(full_name,phone), shipments(*), manual_payment_proofs(*)')
        .eq('store_id', member['store_id'])
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<void> updateOrderStatus(String orderId, String status, {String? note}) async {
    await db.rpc('admin_update_order_status', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_note': note,
    });
  }

  Future<void> verifyPaymentProof(String proofId, bool approved, {String? note}) async {
    await db.rpc('verify_manual_payment_proof', params: {
      'p_proof_id': proofId,
      'p_approved': approved,
      'p_note': note,
    });
  }

  Future<void> updateShipmentStatus({
    required String shipmentId,
    required String status,
    String? description,
    String? location,
    String? driverName,
    String? driverPhone,
    String? trackingNumber,
  }) async {
    await db.rpc('update_shipment_status', params: {
      'p_shipment_id': shipmentId,
      'p_status': status,
      'p_description': description,
      'p_location': location,
      'p_driver_name': driverName,
      'p_driver_phone': driverPhone,
      'p_tracking_number': trackingNumber,
    });
  }

  Future<List<Map<String, dynamic>>> vouchers() async {
    final data = await db.from('vouchers').select().order('created_at', ascending: false);
    return _maps(data);
  }
}
