import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminCategoriesScreen extends StatefulWidget {
  const SuperadminCategoriesScreen({super.key});

  @override
  State<SuperadminCategoriesScreen> createState() => _SuperadminCategoriesScreenState();
}

class _SuperadminCategoriesScreenState extends State<SuperadminCategoriesScreen> {
  String? _storeId;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Future.wait([
      SuperadminRepository.instance.categories(storeId: _storeId),
      SuperadminRepository.instance.stores(),
    ]);
  }

  Future<void> _edit(Map<String, dynamic>? category, List<Map<String, dynamic>> stores, List<Map<String, dynamic>> allCategories) async {
    if (stores.isEmpty) return;
    var storeId = category?['store_id']?.toString() ?? _storeId ?? stores.first['id'].toString();
    final name = TextEditingController(text: category?['name']?.toString() ?? '');
    final slug = TextEditingController(text: category?['slug']?.toString() ?? '');
    final icon = TextEditingController(text: category?['icon_name']?.toString() ?? '');
    final sort = TextEditingController(text: category?['sort_order']?.toString() ?? '0');
    var active = category?['is_active'] as bool? ?? true;
    var parentId = category?['parent_id']?.toString() ?? '_none';
    var saving = false;

    List<Map<String, dynamic>> availableParents() => allCategories
        .where((c) => c['store_id']?.toString() == storeId && c['id']?.toString() != category?['id']?.toString())
        .toList();

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          final parents = availableParents();
          if (parentId != '_none' && !parents.any((c) => c['id']?.toString() == parentId)) parentId = '_none';
          return AlertDialog(
            title: Text(category == null ? 'Tambah Kategori' : 'Edit Kategori'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: storeId,
                      decoration: const InputDecoration(labelText: 'Toko *'),
                      items: stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-'))).toList(),
                      onChanged: category != null || saving
                          ? null
                          : (v) => setDialogState(() {
                                storeId = v ?? storeId;
                                parentId = '_none';
                              }),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Nama kategori *'),
                      onChanged: (value) {
                        if (category == null && slug.text.trim().isEmpty) slug.text = slugify(value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: slug, decoration: const InputDecoration(labelText: 'Slug *')),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: parentId,
                      decoration: const InputDecoration(labelText: 'Kategori induk'),
                      items: [
                        const DropdownMenuItem(value: '_none', child: Text('Tanpa induk')),
                        ...parents.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name']?.toString() ?? '-'))),
                      ],
                      onChanged: saving ? null : (v) => setDialogState(() => parentId = v ?? '_none'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: icon, decoration: const InputDecoration(labelText: 'Icon name', hintText: 'contoh: rice_bowl'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Urutan'))),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kategori aktif'),
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
                          await SuperadminRepository.instance.saveCategory(
                            id: category?['id']?.toString(),
                            storeId: storeId,
                            parentId: parentId == '_none' ? null : parentId,
                            name: name.text,
                            slug: slug.text,
                            iconName: icon.text,
                            sortOrder: int.tryParse(sort.text.trim()) ?? 0,
                            isActive: active,
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
          );
        },
      ),
    );

    name.dispose();
    slug.dispose();
    icon.dispose();
    sort.dispose();
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori Global', style: TextStyle(fontWeight: FontWeight.w900))),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat kategori: ${friendlyError(snapshot.error!)}'));
          final categories = snapshot.data![0] as List<Map<String, dynamic>>;
          final stores = snapshot.data![1] as List<Map<String, dynamic>>;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: DropdownButtonFormField<String>(
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
              ),
              Expanded(
                child: categories.isEmpty
                    ? const Center(child: Text('Belum ada kategori.'))
                    : RefreshIndicator(
                        onRefresh: () async => setState(_reload),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: categories.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final c = categories[i];
                            return Container(
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
                              child: ListTile(
                                onTap: () => _edit(c, stores, categories),
                                leading: CircleAvatar(
                                  backgroundColor: c['is_active'] == true ? const Color(0xFFFFECEC) : const Color(0xFFF2F2F2),
                                  child: const Icon(Icons.category_outlined, color: AppTheme.primary),
                                ),
                                title: Text(c['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text('${c['store_name']} • ${c['product_count'] ?? 0} produk${c['parent_name'] == null ? '' : ' • induk: ${c['parent_name']}'} • ${c['is_active'] == true ? 'aktif' : 'nonaktif'}', style: const TextStyle(fontSize: 12)),
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
          final categories = snapshot.data == null ? <Map<String, dynamic>>[] : snapshot.data![0] as List<Map<String, dynamic>>;
          return FloatingActionButton.extended(
            onPressed: stores.isEmpty ? null : () => _edit(null, stores, categories),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Kategori'),
          );
        },
      ),
    );
  }
}
