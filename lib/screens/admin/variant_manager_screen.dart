import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/variant_repository.dart';

class VariantManagerScreen extends StatefulWidget {
  const VariantManagerScreen({super.key, required this.productId});
  final String productId;

  @override
  State<VariantManagerScreen> createState() => _VariantManagerScreenState();
}

class _VariantManagerScreenState extends State<VariantManagerScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = VariantRepository.instance.load(widget.productId);

  Future<void> _addOption() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Opsi'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nama opsi', hintText: 'Contoh: Ukuran, Warna')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim().isNotEmpty), child: const Text('Tambah')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await VariantRepository.instance.addOption(widget.productId, c.text);
        if (mounted) setState(_reload);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    c.dispose();
  }

  Future<void> _addValue(Map<String, dynamic> option) async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nilai ${option['name']}'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Nilai', hintText: 'Contoh: Merah, XL, 1 kg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim().isNotEmpty), child: const Text('Tambah')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await VariantRepository.instance.addOptionValue(option['id'] as String, c.text);
        if (mounted) setState(_reload);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    c.dispose();
  }

  Map<String, String> _selectedLinks(Map<String, dynamic> variant, List<Map<String, dynamic>> links) {
    final out = <String, String>{};
    for (final link in links.where((e) => e['variant_id'] == variant['id'])) {
      final value = link['product_option_values'];
      if (value is Map && value['option_id'] != null) out[value['option_id'].toString()] = link['option_value_id'].toString();
    }
    return out;
  }

  int _stock(Map<String, dynamic> variant, List inventory) => inventory
      .where((e) => (e as Map)['variant_id'] == variant['id'])
      .fold<int>(0, (sum, e) => sum + (((e as Map)['available_qty'] ?? 0) as num).toInt());

  Future<void> _editVariant(Map<String, dynamic> product, List<Map<String, dynamic>> options, List<Map<String, dynamic>> links, [Map<String, dynamic>? variant]) async {
    final name = TextEditingController(text: variant?['name']?.toString() ?? '');
    final sku = TextEditingController(text: variant?['sku']?.toString() ?? '');
    final barcode = TextEditingController(text: variant?['barcode']?.toString() ?? '');
    final price = TextEditingController(text: variant?['price_override'] == null ? '' : (variant!['price_override'] as num).toInt().toString());
    final weight = TextEditingController(text: '${variant?['weight_grams'] ?? 0}');
    final inventory = product['inventory'] as List? ?? [];
    final initialStock = variant == null ? 0 : _stock(variant, inventory);
    final stock = TextEditingController(text: '$initialStock');
    final reason = TextEditingController();
    var active = variant?['is_active'] != false;
    final selected = variant == null ? <String, String>{} : _selectedLinks(variant, links);
    var saving = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(variant == null ? 'Tambah Varian' : 'Edit Varian'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama varian *')),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: sku, decoration: const InputDecoration(labelText: 'SKU'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: barcode, decoration: const InputDecoration(labelText: 'Barcode'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: price, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Harga varian', hintText: 'Default ${rupiah((product['price'] ?? 0) as num)}'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: weight, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Berat (gram)'))),
                  ]),
                  if (options.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...options.map((option) {
                      final values = (option['product_option_values'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField<String>(
                          initialValue: selected[option['id'].toString()],
                          decoration: InputDecoration(labelText: option['name']?.toString() ?? 'Opsi'),
                          items: values.map((v) => DropdownMenuItem(value: v['id'].toString(), child: Text(v['value']?.toString() ?? '-'))).toList(),
                          onChanged: (v) => setDialogState(() {
                            if (v == null) {
                              selected.remove(option['id'].toString());
                            } else {
                              selected[option['id'].toString()] = v;
                            }
                          }),
                        ),
                      );
                    }),
                  ],
                  Row(children: [
                    Expanded(child: TextField(controller: stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stok tersedia *'))),
                    const SizedBox(width: 8),
                    Expanded(child: SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktif'), value: active, onChanged: saving ? null : (v) => setDialogState(() => active = v))),
                  ]),
                  if (variant != null) ...[
                    const SizedBox(height: 8),
                    TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Alasan perubahan stok', hintText: 'Wajib jika stok berubah')),
                  ],
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
                      final parsedStock = int.tryParse(stock.text);
                      if (name.text.trim().isEmpty || parsedStock == null || parsedStock < 0) return;
                      if (options.isNotEmpty && selected.length != options.length) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih satu nilai untuk setiap opsi.')));
                        return;
                      }
                      if (variant != null && parsedStock != initialStock && reason.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Isi alasan perubahan stok.')));
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await VariantRepository.instance.saveVariant(
                          productId: widget.productId,
                          variantId: variant?['id']?.toString(),
                          name: name.text,
                          sku: sku.text,
                          barcode: barcode.text,
                          priceOverride: num.tryParse(price.text),
                          weightGrams: int.tryParse(weight.text) ?? 0,
                          stock: parsedStock,
                          active: active,
                          optionValueIds: selected.values.toList(),
                          stockReason: variant == null ? 'Stok awal varian' : reason.text,
                        );
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
    name.dispose(); sku.dispose(); barcode.dispose(); price.dispose(); weight.dispose(); stock.dispose(); reason.dispose();
    if (ok == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Opsi & Varian Produk')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Gagal memuat varian: ${friendlyError(snapshot.error!)}'));
            final data = snapshot.data!;
            final product = data['product'] as Map<String, dynamic>;
            final options = data['options'] as List<Map<String, dynamic>>;
            final links = data['links'] as List<Map<String, dynamic>>;
            final variants = (product['product_variants'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final inventory = product['inventory'] as List? ?? [];
            return RefreshIndicator(
              onRefresh: () async { setState(_reload); await _future; },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(product['name']?.toString() ?? 'Produk', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  const Text('Buat opsi lebih dulu, lalu kombinasikan nilainya menjadi varian dengan SKU, harga, berat, dan stok sendiri.', style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 16),
                  Row(children: [
                    const Expanded(child: Text('Opsi Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                    TextButton.icon(onPressed: _addOption, icon: const Icon(Icons.add_rounded), label: const Text('Opsi')),
                  ]),
                  if (options.isEmpty)
                    const _Info(text: 'Belum ada opsi. Produk tanpa varian tetap bisa memakai stok utama.')
                  else
                    ...options.map((option) {
                      final values = (option['product_option_values'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
                      return _Card(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(option['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))),
                            IconButton(onPressed: () => _addValue(option), icon: const Icon(Icons.add_circle_outline_rounded)),
                          ]),
                          if (values.isEmpty) const Text('Belum ada nilai.', style: TextStyle(color: AppTheme.textSecondary)),
                          if (values.isNotEmpty)
                            Wrap(spacing: 7, runSpacing: 7, children: values.map((v) => Chip(label: Text(v['value']?.toString() ?? '-'))).toList()),
                        ]),
                      );
                    }),
                  const SizedBox(height: 18),
                  Row(children: [
                    const Expanded(child: Text('Varian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                    FilledButton.tonalIcon(onPressed: () => _editVariant(product, options, links), icon: const Icon(Icons.add_rounded), label: const Text('Varian')),
                  ]),
                  const SizedBox(height: 8),
                  if (variants.isEmpty)
                    const _Info(text: 'Belum ada varian. Stok utama produk yang digunakan.')
                  else
                    ...variants.map((v) {
                      final selectedLinks = _selectedLinks(v, links);
                      final labels = <String>[];
                      for (final option in options) {
                        final values = (option['product_option_values'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
                        final id = selectedLinks[option['id'].toString()];
                        final matches = values.where((x) => x['id'].toString() == id).toList();
                        if (matches.isNotEmpty) labels.add('${option['name']}: ${matches.first['value']}');
                      }
                      return _Card(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () => _editVariant(product, options, links, v),
                          leading: CircleAvatar(backgroundColor: const Color(0xFFFFECEC), child: Text('${_stock(v, inventory)}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800))),
                          title: Text(v['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${labels.join(' • ')}${labels.isEmpty ? '' : '\n'}${v['sku'] ?? 'Tanpa SKU'} • ${v['price_override'] == null ? 'Harga utama' : rupiah(v['price_override'] as num)} • ${v['is_active'] == true ? 'Aktif' : 'Nonaktif'}'),
                          trailing: const Icon(Icons.edit_outlined),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
        child: child,
      );
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: const Color(0xFFF7F7F7), borderRadius: BorderRadius.circular(10)),
        child: Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
      );
}
