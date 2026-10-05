import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'shop_repository.dart';

class ProductGalleryRepository {
  ProductGalleryRepository._();
  static final instance = ProductGalleryRepository._();

  SupabaseClient get db => Supabase.instance.client;

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<List<Map<String, dynamic>>> images(String productId) async {
    final rows = await db
        .from('product_images')
        .select()
        .eq('product_id', productId)
        .order('sort_order')
        .order('created_at');
    return _maps(rows);
  }

  Future<String> _authorizedStoreId(String? requestedStoreId) async {
    final member = await ShopRepository.instance.membership();
    if (requestedStoreId == null) {
      if (member == null) throw StateError('Not authorized');
      return member['store_id'].toString();
    }
    if (member != null && member['store_id'].toString() == requestedStoreId) {
      return requestedStoreId;
    }
    final superAdmin = await db.rpc('is_platform_super_admin');
    if (superAdmin != true) throw StateError('Not authorized');
    return requestedStoreId;
  }

  Future<String> upload({
    required String productId,
    required XFile file,
    String? storeId,
    bool makePrimary = false,
  }) async {
    final authorizedStoreId = await _authorizedStoreId(storeId);

    final rawExt = file.path.split('.').last.toLowerCase();
    final ext = rawExt == 'jpeg' ? 'jpg' : rawExt;
    if (!{'jpg', 'png', 'webp'}.contains(ext)) {
      throw StateError('Format gambar harus JPG, PNG, atau WebP.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('Ukuran gambar maksimal 5 MB.');
    }
    final path = '$authorizedStoreId/$productId/${DateTime.now().microsecondsSinceEpoch}.$ext';
    final mime = file.mimeType ?? (ext == 'jpg' ? 'image/jpeg' : 'image/$ext');
    await db.storage.from('product-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mime, upsert: false),
        );

    try {
      final existing = await images(productId);
      final shouldPrimary = makePrimary || existing.isEmpty;
      if (shouldPrimary) {
        await db.from('product_images').update({'is_primary': false}).eq('product_id', productId);
      }
      final url = db.storage.from('product-images').getPublicUrl(path);
      final row = await db.from('product_images').insert({
        'product_id': productId,
        'image_url': url,
        'storage_path': path,
        'sort_order': existing.length,
        'is_primary': shouldPrimary,
      }).select('id').single();
      return row['id'] as String;
    } catch (_) {
      await db.storage.from('product-images').remove([path]);
      rethrow;
    }
  }

  Future<void> setPrimary({required String productId, required String imageId}) async {
    await db.from('product_images').update({'is_primary': false}).eq('product_id', productId);
    await db
        .from('product_images')
        .update({'is_primary': true})
        .eq('product_id', productId)
        .eq('id', imageId);
  }

  Future<void> reorder(String productId, List<String> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await db
          .from('product_images')
          .update({'sort_order': i})
          .eq('product_id', productId)
          .eq('id', orderedIds[i]);
    }
  }

  String? _legacyStoragePath(String url) {
    const marker = '/storage/v1/object/public/product-images/';
    final index = url.indexOf(marker);
    if (index < 0) return null;
    return Uri.decodeComponent(url.substring(index + marker.length));
  }

  Future<void> delete({
    required String productId,
    required Map<String, dynamic> image,
  }) async {
    final id = image['id'].toString();
    final wasPrimary = image['is_primary'] == true;
    await db.from('product_images').delete().eq('product_id', productId).eq('id', id);

    final path = image['storage_path']?.toString() ??
        _legacyStoragePath(image['image_url']?.toString() ?? '');
    if (path != null && path.isNotEmpty) {
      try {
        await db.storage.from('product-images').remove([path]);
      } catch (_) {
        // A missing legacy object must not leave the catalog unusable.
      }
    }

    final remaining = await images(productId);
    if (wasPrimary && remaining.isNotEmpty) {
      await setPrimary(productId: productId, imageId: remaining.first['id'].toString());
    }
    await reorder(productId, remaining.map((e) => e['id'].toString()).toList());
  }
}
