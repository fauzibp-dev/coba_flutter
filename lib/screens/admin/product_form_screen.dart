import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/shop_repository.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});
  final Map<String, dynamic>? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _compare;
  late final TextEditingController _sku;
  late final TextEditingController _stock;
  late Future<List<Map<String, dynamic>>> _categories;
  String? _categoryId;
  bool _active = true;
  bool _featured = false;
  XFile? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?['name']?.toString() ?? '');
    _description = TextEditingController(text: p?['description']?.toString() ?? '');
    _price = TextEditingController(text: p == null ? '' : ((p['price'] ?? 0) as num).toInt().toString());
    _compare = TextEditingController(text: p?['compare_at_price'] == null ? '' : ((p!['compare_at_price']) as num).toInt().toString());
    _sku = TextEditingController(text: p?['sku']?.toString() ?? '');
    final inventory = p?['inventory'] as List? ?? [];
    final stock = inventory.isEmpty ? 0 : ((inventory.first as Map)['available_qty'] ?? 0) as num;
    _stock = TextEditingController(text: p == null ? '' : stock.toInt().toString());
    _categoryId = p?['category_id'] as String?;
    _active = p == null ? true : p['status'] == 'active';
    _featured = p?['is_featured'] == true;
    _categories = ShopRepository.instance.adminCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _compare.dispose();
    _sku.dispose();
    _stock.dispose();
    super.dispose();
  }

  int? _integer(String value) => int.tryParse(value.replaceAll('.', '').replaceAll(',', ''));

  Future<void> _pickImage() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1400,
      imageQuality: 82,
    );
    if (image != null && mounted) setState(() => _image = image);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih kategori produk.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ShopRepository.instance.saveProduct(
        productId: widget.product?['id'] as String?,
        name: _name.text,
        description: _description.text,
        price: _integer(_price.text)!,
        compareAtPrice: _compare.text.trim().isEmpty ? null : _integer(_compare.text),
        categoryId: _categoryId!,
        sku: _sku.text,
        stock: _integer(_stock.text)!,
        active: _active,
        featured: _featured,
        image: _image,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.primaryDark),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? v) => v == null || v.trim().isEmpty ? 'Wajib diisi.' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'Tambah Produk' : 'Edit Produk')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _categories,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final categories = snapshot.data ?? [];
          return Form(
            key: _key,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                    child: _image == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 38, color: AppTheme.textSecondary),
                              SizedBox(height: 8),
                              Text('Pilih foto produk', style: TextStyle(fontWeight: FontWeight.w700)),
                              Text('JPG, PNG, atau WebP maks. 5 MB', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                            ],
                          )
                        : FutureBuilder<Uint8List>(
                            future: _image!.readAsBytes(),
                            builder: (_, bytes) {
                              if (!bytes.hasData) return const Center(child: CircularProgressIndicator());
                              return ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes.data!, fit: BoxFit.cover, width: double.infinity));
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama produk'), validator: _required),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: categories.map((c) => DropdownMenuItem(value: c['id'] as String, child: Text(c['name']?.toString() ?? '-'))).toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _description, minLines: 3, maxLines: 6, decoration: const InputDecoration(labelText: 'Deskripsi produk'), validator: _required),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _price,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Harga jual', prefixText: 'Rp '),
                  validator: (v) => (_integer(v ?? '') ?? 0) <= 0 ? 'Harga harus lebih dari 0.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(controller: _compare, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga sebelum diskon (opsional)', prefixText: 'Rp ')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU (opsional)'))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _stock,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Stok'),
                        validator: (v) => (_integer(v ?? '') ?? -1) < 0 ? 'Stok tidak valid.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tampilkan di katalog'),
                  subtitle: const Text('Produk aktif dapat dilihat pelanggan.'),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Produk unggulan'),
                  value: _featured,
                  onChanged: (v) => setState(() => _featured = v),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan Produk')),
              ],
            ),
          );
        },
      ),
    );
  }
}
