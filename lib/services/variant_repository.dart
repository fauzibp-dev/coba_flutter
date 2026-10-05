import 'package:supabase_flutter/supabase_flutter.dart';

class VariantRepository {
  VariantRepository._();
  static final instance = VariantRepository._();
  SupabaseClient get db => Supabase.instance.client;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<Map<String, dynamic>> load(String productId) async {
    final product = Map<String, dynamic>.from(await db
        .from('products')
        .select('id,name,store_id,price,product_variants(*),inventory(*)')
        .eq('id', productId)
        .single());
    final options = _maps(await db
        .from('product_options')
        .select('*, product_option_values(*)')
        .eq('product_id', productId)
        .order('sort_order'));
    final links = _maps(await db
        .from('variant_option_values')
        .select('variant_id,option_value_id,product_option_values(value,option_id)'));
    return {'product': product, 'options': options, 'links': links};
  }

  Future<String> addOption(String productId, String name) async {
    final row = await db.from('product_options').insert({
      'product_id': productId,
      'name': name.trim(),
      'sort_order': 0,
    }).select('id').single();
    return row['id'] as String;
  }

  Future<String> addOptionValue(String optionId, String value) async {
    final row = await db.from('product_option_values').insert({
      'option_id': optionId,
      'value': value.trim(),
      'sort_order': 0,
    }).select('id').single();
    return row['id'] as String;
  }

  Future<void> deleteOptionValue(String id) => db.from('product_option_values').delete().eq('id', id);
  Future<void> deleteOption(String id) => db.from('product_options').delete().eq('id', id);

  Future<String> saveVariant({
    required String productId,
    String? variantId,
    required String name,
    String? sku,
    String? barcode,
    num? priceOverride,
    int weightGrams = 0,
    required int stock,
    bool active = true,
    List<String> optionValueIds = const [],
    String? stockReason,
  }) async {
    final value = await db.rpc('save_product_variant', params: {
      'p_product_id': productId,
      'p_variant_id': variantId,
      'p_name': name.trim(),
      'p_sku': sku?.trim(),
      'p_barcode': barcode?.trim(),
      'p_price_override': priceOverride,
      'p_weight_grams': weightGrams,
      'p_stock': stock,
      'p_is_active': active,
      'p_option_value_ids': optionValueIds,
      'p_stock_reason': stockReason?.trim(),
    });
    return value as String;
  }

  Future<void> archiveVariant(String id) => db.rpc('archive_product_variant', params: {'p_variant_id': id});
}
