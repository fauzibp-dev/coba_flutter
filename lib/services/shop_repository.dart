import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
        .eq('slug', 'koperasi-merah-putih-kerten')
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<List<Map<String, dynamic>>> categories() async {
    final data = await db
        .from('categories')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return _maps(data);
  }

  Future<List<Map<String, dynamic>>> banners() async {
    final data = await db
        .from('banners')
        .select()
        .eq('is_active', true)
        .order('sort_order');
    return _maps(data);
  }

  Future<List<Map<String, dynamic>>> products({
    String? search,
    String? categoryId,
    bool featuredOnly = false,
  }) async {
    dynamic query = db.from('products').select(
          '*, categories(name), product_images(*), product_variants(*), inventory(*)',
        );
    query = query.eq('status', 'active');
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
          '*, categories(name), product_images(*), product_variants(*), inventory(*), reviews(rating,comment,created_at)',
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

  Future<void> addToCart(
    String productId, {
    String? variantId,
    int quantity = 1,
  }) async {
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    await db.rpc('add_to_cart', params: {
      'p_product_id': productId,
      'p_variant_id': variantId,
      'p_quantity': quantity,
    });
  }

  Future<List<Map<String, dynamic>>> cartItems() async {
    if (!isSignedIn) return [];
    final cart = await db
        .from('carts')
        .select('id')
        .eq('user_id', user!.id)
        .maybeSingle();
    if (cart == null) return [];
    final data = await db
        .from('cart_items')
        .select('*, products(*, product_images(*), inventory(*)), product_variants(*)')
        .eq('cart_id', cart['id'])
        .order('created_at');
    return _maps(data);
  }

  Future<void> setCartQuantity(String itemId, int quantity) async {
    await db.rpc('set_cart_quantity', params: {
      'p_item_id': itemId,
      'p_quantity': quantity,
    });
  }

  Future<void> removeCartItem(String itemId) async {
    await db.rpc('remove_cart_item', params: {'p_item_id': itemId});
  }

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

  Future<String> saveAddress({
    String? id,
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
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    if (isDefault) {
      await db
          .from('addresses')
          .update({'is_default': false})
          .eq('user_id', user!.id);
    }
    final payload = {
      'user_id': user!.id,
      'label': label.trim(),
      'recipient_name': recipientName.trim(),
      'phone': phone.trim(),
      'province': province.trim(),
      'city': city.trim(),
      'district': district.trim(),
      'address_line': addressLine.trim(),
      'postal_code': postalCode?.trim().isEmpty == true ? null : postalCode?.trim(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'is_default': isDefault,
    };
    if (id == null) {
      final row = await db.from('addresses').insert(payload).select('id').single();
      return row['id'] as String;
    }
    await db.from('addresses').update(payload).eq('id', id);
    return id;
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
  }) =>
      saveAddress(
        label: label,
        recipientName: recipientName,
        phone: phone,
        province: province,
        city: city,
        district: district,
        addressLine: addressLine,
        postalCode: postalCode,
        notes: notes,
        isDefault: isDefault,
      );

  Future<void> deleteAddress(String id) async {
    await db.from('addresses').delete().eq('id', id);
  }

  Future<String> checkout({
    String? addressId,
    required String paymentMethod,
    required String shippingMethod,
    required String clientRequestId,
    String? voucherCode,
    String? notes,
  }) async {
    final result = await db.rpc('create_checkout', params: {
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
        .select('*, order_items(*)')
        .eq('user_id', user!.id)
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<Map<String, dynamic>> orderDetail(String orderId) async {
    final data = await db
        .from('orders')
        .select(
          '*, order_items(*, reviews(*)), order_status_history(*), payments(*)',
        )
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

  Future<void> submitReview({
    required String orderItemId,
    required String productId,
    required int rating,
    String? comment,
  }) async {
    await db.rpc('submit_review', params: {
      'p_order_item_id': orderItemId,
      'p_product_id': productId,
      'p_rating': rating,
      'p_comment': comment,
    });
  }

  Future<String> requestReturn({
    required String orderId,
    required String reason,
    String? description,
  }) async {
    final result = await db.rpc('request_return', params: {
      'p_order_id': orderId,
      'p_reason': reason.trim(),
      'p_description': description?.trim(),
    });
    return result as String;
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

  Future<void> markNotificationRead(String id) async {
    await db.rpc('mark_notification_read', params: {'p_notification_id': id});
  }

  Future<String> conversationId() async {
    final shop = await store();
    final result = await db.rpc(
      'get_or_create_conversation',
      params: {'p_store_id': shop['id']},
    );
    return result as String;
  }

  Future<List<Map<String, dynamic>>> messages(String conversationId) async {
    final data = await db
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at');
    return _maps(data);
  }

  Future<void> sendMessage(String conversationId, String body) async {
    if (!isSignedIn) throw StateError('AUTH_REQUIRED');
    final text = body.trim();
    if (text.isEmpty) return;
    await db.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user!.id,
      'message_type': 'text',
      'body': text,
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
      await db.from('wishlists').insert({
        'user_id': user!.id,
        'product_id': productId,
      });
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
        .select('*, categories(name), product_images(*), inventory(*)')
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
    required String stockReason,
    XFile? image,
  }) async {
    final member = await membership();
    if (member == null) throw StateError('Not authorized');
    final storeId = member['store_id'] as String;

    final result = await db.rpc('save_product_admin', params: {
      'p_store_id': storeId,
      'p_product_id': productId,
      'p_name': name.trim(),
      'p_description': description.trim(),
      'p_price': price,
      'p_compare_at_price': compareAtPrice,
      'p_category_id': categoryId,
      'p_sku': sku.trim(),
      'p_stock': stock,
      'p_active': active,
      'p_featured': featured,
      'p_stock_reason': stockReason.trim(),
    });
    final id = result as String;

    if (image != null) {
      final oldRows = _maps(await db
          .from('product_images')
          .select('id,image_url')
          .eq('product_id', id));
      final bytes = await image.readAsBytes();
      final rawExt = image.path.split('.').last.toLowerCase();
      final ext = {'jpg', 'jpeg', 'png', 'webp'}.contains(rawExt) ? rawExt : 'jpg';
      final path = '$storeId/$id/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await db.storage.from('product-images').uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: image.mimeType, upsert: false),
          );
      final url = db.storage.from('product-images').getPublicUrl(path);
      await db.from('product_images').update({'is_primary': false}).eq('product_id', id);
      final inserted = await db.from('product_images').insert({
        'product_id': id,
        'image_url': url,
        'is_primary': true,
        'sort_order': 0,
      }).select('id').single();
      final newId = inserted['id'];
      if (oldRows.isNotEmpty) {
        await db
            .from('product_images')
            .delete()
            .eq('product_id', id)
            .neq('id', newId);
        final paths = <String>[];
        for (final row in oldRows) {
          final oldUrl = row['image_url']?.toString() ?? '';
          const marker = '/object/public/product-images/';
          final index = oldUrl.indexOf(marker);
          if (index >= 0) paths.add(Uri.decodeComponent(oldUrl.substring(index + marker.length)));
        }
        if (paths.isNotEmpty) {
          try {
            await db.storage.from('product-images').remove(paths);
          } catch (_) {
            // DB now points at the new primary image; orphan cleanup can be retried later.
          }
        }
      }
    }
    return id;
  }

  Future<void> archiveProduct(String id) =>
      db.from('products').update({'status': 'archived'}).eq('id', id);

  Future<List<Map<String, dynamic>>> adminOrders() async {
    final member = await membership();
    if (member == null) return [];
    final data = await db
        .from('orders')
        .select('*, order_items(*), profiles(full_name,phone)')
        .eq('store_id', member['store_id'])
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<void> updateOrderStatus(
    String orderId,
    String status, {
    String? note,
  }) async {
    await db.rpc('admin_update_order_status', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_note': note,
    });
  }

  Future<List<Map<String, dynamic>>> adminReturns() async {
    final member = await membership();
    if (member == null) return [];
    final data = await db
        .from('returns')
        .select('*, orders!inner(order_number,store_id,total_amount)')
        .eq('orders.store_id', member['store_id'])
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<void> updateReturnStatus(String returnId, String status) async {
    await db.rpc('admin_update_return_status', params: {
      'p_return_id': returnId,
      'p_status': status,
    });
  }

  Future<List<Map<String, dynamic>>> vouchers() async {
    final member = await membership();
    if (member == null) return [];
    final data = await db
        .from('vouchers')
        .select()
        .eq('store_id', member['store_id'])
        .order('created_at', ascending: false);
    return _maps(data);
  }

  Future<void> saveVoucher({
    String? id,
    required String code,
    required String title,
    required String discountType,
    required num discountValue,
    required num minimumPurchase,
    num? maximumDiscount,
    int? usageLimit,
    required int usagePerUser,
    required bool active,
  }) async {
    final member = await membership();
    if (member == null) throw StateError('Not authorized');
    final payload = {
      'store_id': member['store_id'],
      'code': code.trim().toUpperCase(),
      'title': title.trim(),
      'discount_type': discountType,
      'discount_value': discountValue,
      'minimum_purchase': minimumPurchase,
      'maximum_discount': maximumDiscount,
      'usage_limit': usageLimit,
      'usage_per_user': usagePerUser,
      'is_active': active,
    };
    if (id == null) {
      await db.from('vouchers').insert(payload);
    } else {
      await db.from('vouchers').update(payload).eq('id', id);
    }
  }
}
