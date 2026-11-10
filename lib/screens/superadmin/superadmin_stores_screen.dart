import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminStoresScreen extends StatefulWidget {
  const SuperadminStoresScreen({super.key});

  @override
  State<SuperadminStoresScreen> createState() => _SuperadminStoresScreenState();
}

class _SuperadminStoresScreenState extends State<SuperadminStoresScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = SuperadminRepository.instance.stores();

  Future<void> _edit([Map<String, dynamic>? store]) async {
    final name = TextEditingController(text: store?['name']?.toString() ?? '');
    final slug = TextEditingController(text: store?['slug']?.toString() ?? '');
    final description = TextEditingController(text: store?['description']?.toString() ?? '');
    final address = TextEditingController(text: store?['address']?.toString() ?? '');
    final phone = TextEditingController(text: store?['phone']?.toString() ?? '');
    var active = store?['is_active'] as bool? ?? true;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(store == null ? 'Tambah Toko' : 'Edit Toko'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nama toko *'),
                    onChanged: (value) {
                      if (store == null && slug.text.trim().isEmpty) slug.text = slugify(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug *')),
                  const SizedBox(height: 10),
                  TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'Deskripsi')),
                  const SizedBox(height: 10),
                  TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Alamat')),
                  const SizedBox(height: 10),
                  TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor telepon')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Toko aktif'),
                    subtitle: const Text('Toko nonaktif tidak boleh menerima transaksi baru.'),
                    value: active,
                    onChanged: saving ? null : (v) => setDialogState(() => active = v),
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
                      if (name.text.trim().isEmpty || slug.text.trim().isEmpty) return;
                      setDialogState(() => saving = true);
                      try {
                        await SuperadminRepository.instance.saveStore(
                          id: store?['id']?.toString(),
                          name: name.text,
                          slug: slug.text,
                          description: description.text,
                          address: address.text,
                          phone: phone.text,
                          isActive: active,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                        }
                      }
                    },
              child: Text(saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    slug.dispose();
    description.dispose();
    address.dispose();
    phone.dispose();
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toko & Koperasi', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat toko: ${friendlyError(snapshot.error!)}'));
          final stores = snapshot.data ?? [];
          if (stores.isEmpty) return const Center(child: Text('Belum ada toko.'));
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: stores.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = stores[i];
                final active = s['is_active'] == true;
                return Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
                  child: ListTile(
                    onTap: () => _edit(s),
                    leading: CircleAvatar(
                      backgroundColor: active ? const Color(0xFFE8F5E9) : const Color(0xFFF2F2F2),
                      child: Icon(Icons.storefront_rounded, color: active ? const Color(0xFF2E7D32) : AppTheme.textSecondary),
                    ),
                    title: Text(s['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      '${active ? 'Aktif' : 'Nonaktif'} • ${s['product_count'] ?? 0} produk • ${s['order_count'] ?? 0} order • ${s['member_count'] ?? 0} pengelola',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Tambah Toko'),
      ),
    );
  }
}
