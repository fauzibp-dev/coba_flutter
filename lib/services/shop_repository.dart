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
    await claimInitialOwner();
  }

  Future<bool> signUp(String name, String email, String password) async {
    final response = await db.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'full_name': name.trim()},
    );
    if (response.session != null) await claimInitialOwner();
    return response.session != null;
  }

  Future<void> signOut() => db.auth.signOut();

  Future<bool> claimInitialOwner() async {
    if (!isSignedIn) return false;
    final result = await db.rpc('claim_initial_owner');
    return result == true;
  }

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
    if (quantity <= 0) {
      await db.from('cart_items').delete().eq('id', itemId);
    } else {
      await db.from('cart_items').update({'quantity': quantity.clamp(1, 99)}).eq('id', itemId);
    }
  }

  Future<void> removeCartItem(String itemId) =>
      db.from('cart_items').delete().eq('id', itemId);

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

  Future<String> checkout({
    required String addressId,
    required String paymentMethod,
    required String shippingMethod,
    String? voucherCode,
    String? notes,
  }) async {
    final result = await db.rpc('create_checkout', params: {
      'p_address_id': addressId,
      'p_payment_method': paymentMethod,
      'p_shipping_method': shippingMethod,
      'p_voucher_code': voucherCode?.trim().isEmpty == true ? null : voucherCode?.trim(),
      'p_notes': notes?.trim(),
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

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await db.rpc('cancel_my_order', params: {
      'p_order_id': orderId,
      'p_reason': reason,
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
    XFile? image,
  }) async {
    final member = await membership();
    if (member == null) throw StateError('Not authorized');
    final storeId = member['store_id'] as String;
    final payload = <String, dynamic>{
      'store_id': storeId,
      'category_id': categoryId,
      'name': name.trim(),
      'slug': '${slugify(name)}-${DateTime.now().millisecondsSinceEpoch}',
      'description': description.trim(),
      'price': price,
      'compare_at_price': compareAtPrice,
      'sku': sku.trim().isEmpty ? null : sku.trim(),
      'status': active ? 'active' : 'draft',
      'is_featured': featured,
    };

    String id;
    if (productId == null) {
      final row = await db.from('products').insert(payload).select('id').single();
      id = row['id'] as String;
      await db.from('inventory').insert({
        'product_id': id,
        'available_qty': stock,
        'reserved_qty': 0,
      });
      await db.from('inventory_movements').insert({
        'store_id': storeId,
        'product_id': id,
        'movement_type': 'adjustment',
        'quantity': stock,
        'note': 'Initial stock',
        'actor_id': user!.id,
      });
    } else {
      id = productId;
      payload.remove('slug');
      await db.from('products').update(payload).eq('id', id);
      final inventory = await db
          .from('inventory')
          .select('id, available_qty')
          .eq('product_id', id)
          .isFilter('variant_id', null)
          .maybeSingle();
      if (inventory == null) {
        await db.from('inventory').insert({'product_id': id, 'available_qty': stock});
      } else {
        final old = (inventory['available_qty'] as num).toInt();
        await db.from('inventory').update({'available_qty': stock}).eq('id', inventory['id']);
        if (old != stock) {
          await db.from('inventory_movements').insert({
            'store_id': storeId,
            'product_id': id,
            'movement_type': 'adjustment',
            'quantity': stock - old,
            'note': 'Stock edited from admin',
            'actor_id': user!.id,
          });
        }
      }
    }

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

  Future<void> updateOrderStatus(String orderId, String status, {String? note}) async {
    await db.rpc('admin_update_order_status', params: {
      'p_order_id': orderId,
      'p_status': status,
      'p_note': note,
    });
  }

  Future<List<Map<String, dynamic>>> vouchers() async {
    final data = await db.from('vouchers').select().order('created_at', ascending: false);
    return _maps(data);
  }
}
