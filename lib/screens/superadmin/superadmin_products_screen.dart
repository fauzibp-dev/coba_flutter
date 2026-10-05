import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminProductsScreen extends StatefulWidget {
  const SuperadminProductsScreen({super.key});

  @override
  State<SuperadminProductsScreen> createState() => _SuperadminProductsScreenState();
}

class _SuperadminProductsScreenState extends State<SuperadminProductsScreen> {
  final _search = TextEditingController();
  String? _storeId;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _reload() {
    _future = Future.wait([
      SuperadminRepository.instance.products(storeId: _storeId, search: _search.text),
      SuperadminRepository.instance.stores(),
    ]);
  }

  Future<void> _edit(Map<String, dynamic>? product, List<Map<String, dynamic>> stores) async {
    if (stores.isEmpty) return;
    Map<String, dynamic>? detail;
    if (product != null) {
      try {
        detail = await SuperadminRepository.instance.productDetail(product['id'].toString());
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        return;
      }
    }
    if (!mounted) return;

    var storeId = detail?['store_id']?.toString() ?? product?['store_id']?.toString() ?? stores.first['id'].toString();
    var categories = await SuperadminRepository.instance.productCategories(storeId);
    if (!mounted) return;

    final name = TextEditingController(text: detail?['name']?.toString() ?? '');
    final description = TextEditingController(text: detail?['description']?.toString() ?? '');
    final price = TextEditingController(text: detail?['price']?.toString() ?? '');
    final compare = TextEditingController(text: detail?['compare_at_price']?.toString() ?? '');
    final sku = TextEditingController(text: detail?['sku']?.toString() ?? '');
    final inventory = detail?['inventory'] as List? ?? const [];
    final baseInventory = inventory.where((e) => (e as Map)['variant_id'] == null).toList();
    final oldStock = baseInventory.isEmpty ? ((product?['stock'] ?? 0) as num).toInt() : ((baseInventory.first as Map)['available_qty'] as num?)?.toInt() ?? 0;
    final stock = TextEditingController(text: '$oldStock');
    final reason = TextEditingController();
    var status = detail?['status']?.toString() ?? product?['status']?.toString() ?? 'draft';
    var featured = detail?['is_featured'] == true || product?['is_featured'] == true;
    var categoryValue = detail?['category_id']?.toString() ?? '_none';
    var saving = false;
    XFile? selectedImage;
    final images = (detail?['product_images'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final primaryImages = images.where((e) => e['is_primary'] == true).toList();
    final currentImageUrl = primaryImages.isNotEmpty
        ? primaryImages.first['image_url']?.toString()
        : (images.isEmpty ? null : images.first['image_url']?.toString());

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(product == null ? 'Tambah Produk Global' : 'Edit Produk Global'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: storeId,
                    decoration: const InputDecoration(labelText: 'Toko *'),
                    items: stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-'))).toList(),
                    onChanged: product != null || saving
                        ? null
                        : (v) async {
                            if (v == null) return;
                            final next = await SuperadminRepository.instance.productCategories(v);
                            setDialogState(() {
                              storeId = v;
                              categories = next;
                              categoryValue = '_none';
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama produk *')),
                  const SizedBox(height: 10),
                  TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Deskripsi')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: categories.any((c) => c['id']?.toString() == categoryValue) ? categoryValue : '_none',
                    decoration: const InputDecoration(labelText: 'Kategori'),
                    items: [
                      const DropdownMenuItem(value: '_none', child: Text('Tanpa kategori')),
                      ...categories.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']?.toString() ?? '-'))),
                    ],
                    onChanged: saving ? null : (v) => setDialogState(() => categoryValue = v ?? '_none'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga *'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: compare, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga coret'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU'))),
                      const SizedBox(width: 8),
                      Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stok *'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: reason, decoration: const InputDecoration(labelText: 'Alasan perubahan stok', hintText: 'Wajib jika stok berubah')),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(value: 'active', child: Text('Aktif')),
                      DropdownMenuItem(value: 'inactive', child: Text('Nonaktif')),
                      DropdownMenuItem(value: 'archived', child: Text('Arsip')),
                    ],
                    onChanged: saving ? null : (v) => setDialogState(() => status = v ?? status),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Produk unggulan'),
                    value: featured,
                    onChanged: saving ? null : (v) => setDialogState(() => featured = v),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(9)),
                        child: currentImageUrl == null
                            ? const Icon(Icons.image_outlined, color: AppTheme.textSecondary)
                            : Image.network(currentImageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Foto utama', style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(selectedImage?.name ?? (currentImageUrl == null ? 'Belum ada gambar' : 'Gambar saat ini'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            const SizedBox(height: 6),
                            OutlinedButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1600);
                                      if (picked != null) setDialogState(() => selectedImage = picked);
                                    },
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: Text(selectedImage == null ? 'Pilih gambar' : 'Ganti pilihan'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('JPG/PNG/WebP maksimal 5 MB. Gambar baru menjadi foto utama.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final parsedPrice = num.tryParse(price.text.replaceAll(',', '.'));
                      final parsedCompare = compare.text.trim().isEmpty ? null : num.tryParse(compare.text.replaceAll(',', '.'));
                      final parsedStock = int.tryParse(stock.text.trim());
                      if (name.text.trim().isEmpty || parsedPrice == null || parsedPrice <= 0 || parsedStock == null || parsedStock < 0) return;
                      if (product != null && parsedStock != oldStock && reason.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alasan perubahan stok wajib diisi.')));
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final productId = await SuperadminRepository.instance.saveProduct(
                          id: product?['id']?.toString(),
                          storeId: storeId,
                          name: name.text,
                          description: description.text,
                          price: parsedPrice,
                          compareAtPrice: parsedCompare,
                          categoryId: categoryValue == '_none' ? null : categoryValue,
                          sku: sku.text,
                          stock: parsedStock,
                          status: status,
                          featured: featured,
                          stockReason: reason.text,
                        );
                        if (selectedImage != null) {
                          await SuperadminRepository.instance.uploadProductImage(storeId: storeId, productId: productId, image: selectedImage!);
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                      }
                    },
              child: Text(saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    description.dispose();
    price.dispose();
    compare.dispose();
    sku.dispose();
    stock.dispose();
    reason.dispose();
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Katalog Global', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat katalog: ${friendlyError(snapshot.error!)}'));
          final products = snapshot.data![0] as List<Map<String, dynamic>>;
          final stores = snapshot.data![1] as List<Map<String, dynamic>>;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _storeId ?? '_all',
                      decoration: const InputDecoration(labelText: 'Filter toko'),
                      items: [
                        const DropdownMenuItem(value: '_all', child: Text('Semua toko')),
                        ...stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-'))),
                      ],
                      onChanged: (v) => setState(() {
                        _storeId = v == '_all' ? null : v;
                        _reload();
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => setState(_reload),
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Cari produk / SKU'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: products.isEmpty
                    ? const Center(child: Text('Produk tidak ditemukan.'))
                    : RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: products.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final p = products[i];
                            return Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
                              child: ListTile(
                                onTap: () => _edit(p, stores),
                                leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                                title: Text(p['name']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text('${p['store_name']} • ${rupiah((p['price'] ?? 0) as num)} • stok ${p['stock'] ?? 0}\n${p['status']} • ${p['sku'] ?? 'tanpa SKU'}', style: const TextStyle(fontSize: 12)),
                                isThreeLine: true,
                                trailing: const Icon(Icons.edit_outlined),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final stores = snapshot.data == null ? <Map<String, dynamic>>[] : snapshot.data![1] as List<Map<String, dynamic>>;
          return FloatingActionButton.extended(
            onPressed: stores.isEmpty ? null : () => _edit(null, stores),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Produk'),
          );
        },
      ),
    );
  }
}
