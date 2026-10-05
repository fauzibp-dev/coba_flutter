import 'package:supabase_flutter/supabase_flutter.dart';

import 'shop_repository.dart';

class AdminOperationsRepository {
  AdminOperationsRepository._();
  static final instance = AdminOperationsRepository._();
  SupabaseClient get db => Supabase.instance.client;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<String> _storeId() async {
    final member = await ShopRepository.instance.membership();
    if (member == null) throw StateError('Not authorized');
    return member['store_id'] as String;
  }

  Future<List<Map<String, dynamic>>> shipments() async {
    final storeId = await _storeId();
    return _maps(await db
        .from('shipments')
        .select('*, orders(order_number,status,user_id,total_amount), shipment_events(*)')
        .eq('store_id', storeId)
        .order('created_at', ascending: false));
  }

  Future<void> updateShipment({
    required String id,
    required String status,
    String? description,
    String? location,
    String? driverName,
    String? driverPhone,
    String? trackingNumber,
  }) async {
    await db.rpc('update_shipment_status', params: {
      'p_shipment_id': id,
      'p_status': status,
      'p_description': description,
      'p_location': location,
      'p_driver_name': driverName,
      'p_driver_phone': driverPhone,
      'p_tracking_number': trackingNumber,
    });
  }

  Future<List<Map<String, dynamic>>> paymentProofs() async {
    final storeId = await _storeId();
    return _maps(await db
        .from('manual_payment_proofs')
        .select('*, orders!inner(order_number,store_id,total_amount,payment_status,status)')
        .eq('orders.store_id', storeId)
        .order('created_at', ascending: false));
  }

  Future<void> verifyPaymentProof(String proofId, bool approved, {String? note}) async {
    await db.rpc('verify_manual_payment_proof', params: {
      'p_proof_id': proofId,
      'p_approved': approved,
      'p_note': note,
    });
  }

  Future<String> signedPaymentProofUrl(String path) => db.storage.from('payment-proofs').createSignedUrl(path, 900);

  Future<Map<String, dynamic>> settings() async {
    final storeId = await _storeId();
    final row = await db.from('store_settings').select().eq('store_id', storeId).single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> saveSettings({
    required num deliveryFee,
    num? freeShippingThreshold,
    required int paymentTimeoutMinutes,
    String? bankName,
    String? bankAccountName,
    String? bankAccountNumber,
    String? supportPhone,
    required int returnWindowDays,
  }) async {
    final storeId = await _storeId();
    await db.from('store_settings').upsert({
      'store_id': storeId,
      'local_delivery_fee': deliveryFee,
      'free_shipping_threshold': freeShippingThreshold,
      'manual_payment_timeout_minutes': paymentTimeoutMinutes,
      'bank_name': bankName?.trim(),
      'bank_account_name': bankAccountName?.trim(),
      'bank_account_number': bankAccountNumber?.trim(),
      'support_phone': supportPhone?.trim(),
      'return_window_days': returnWindowDays,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> deliveryZones() async {
    final storeId = await _storeId();
    return _maps(await db.from('delivery_zones').select().eq('store_id', storeId).order('priority', ascending: false));
  }

  Future<void> saveDeliveryZone({
    String? id,
    required String name,
    String? city,
    String? district,
    required num fee,
    num? freeShippingThreshold,
    int priority = 0,
    bool active = true,
  }) async {
    final storeId = await _storeId();
    final data = {
      'store_id': storeId,
      'name': name.trim(),
      'city': city?.trim().isEmpty == true ? null : city?.trim(),
      'district': district?.trim().isEmpty == true ? null : district?.trim(),
      'fee': fee,
      'free_shipping_threshold': freeShippingThreshold,
      'priority': priority,
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await db.from('delivery_zones').insert(data);
    } else {
      await db.from('delivery_zones').update(data).eq('id', id);
    }
  }

  Future<void> deleteDeliveryZone(String id) async => db.from('delivery_zones').delete().eq('id', id);

  Future<List<Map<String, dynamic>>> suppliers() async {
    final storeId = await _storeId();
    return _maps(await db.from('suppliers').select().eq('store_id', storeId).order('name'));
  }

  Future<String> saveSupplier({String? id, required String name, String? phone, String? email, String? address}) async {
    final storeId = await _storeId();
    final values = {'store_id': storeId, 'name': name.trim(), 'phone': phone?.trim(), 'email': email?.trim(), 'address': address?.trim(), 'updated_at': DateTime.now().toUtc().toIso8601String()};
    if (id == null) {
      final row = await db.from('suppliers').insert(values).select('id').single();
      return row['id'] as String;
    }
    await db.from('suppliers').update(values).eq('id', id);
    return id;
  }

  Future<List<Map<String, dynamic>>> stocktakes() async {
    final storeId = await _storeId();
    return _maps(await db.from('stocktakes').select('*, stocktake_items(*)').eq('store_id', storeId).order('created_at', ascending: false));
  }

  Future<String> createStocktake({String? notes}) async {
    final storeId = await _storeId();
    final userId = db.auth.currentUser!.id;
    final row = await db.from('stocktakes').insert({'store_id': storeId, 'status': 'counting', 'notes': notes?.trim(), 'created_by': userId}).select('id').single();
    final id = row['id'] as String;
    final inventory = _maps(await db.from('inventory').select('product_id,variant_id,available_qty,products!inner(store_id)').eq('products.store_id', storeId));
    if (inventory.isNotEmpty) {
      await db.from('stocktake_items').insert(inventory.map((e) => {
            'stocktake_id': id,
            'product_id': e['product_id'],
            'variant_id': e['variant_id'],
            'system_qty': e['available_qty'],
          }).toList());
    }
    return id;
  }

  Future<void> setStocktakeCount(String itemId, int count) async {
    if (count < 0) throw StateError('Count cannot be negative');
    await db.from('stocktake_items').update({'counted_qty': count}).eq('id', itemId);
  }

  Future<void> completeStocktake(String id) async => db.rpc('complete_stocktake', params: {'p_stocktake_id': id});

  Future<List<Map<String, dynamic>>> purchaseOrders() async {
    final storeId = await _storeId();
    return _maps(await db
        .from('purchase_orders')
        .select('*, suppliers(name), purchase_order_items(*, products(name), product_variants(name))')
        .eq('store_id', storeId)
        .order('created_at', ascending: false));
  }

  Future<String> createPurchaseOrder({String? supplierId, String? notes, DateTime? expectedAt}) async {
    final storeId = await _storeId();
    final seq = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
    final row = await db.from('purchase_orders').insert({
      'store_id': storeId,
      'supplier_id': supplierId,
      'po_number': 'PO-$seq',
      'status': 'draft',
      'expected_at': expectedAt?.toUtc().toIso8601String(),
      'notes': notes?.trim(),
      'created_by': db.auth.currentUser!.id,
    }).select('id').single();
    return row['id'] as String;
  }
}
