import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';
import '../admin/product_gallery_screen.dart';

class SuperadminGalleryScreen extends StatefulWidget {
  const SuperadminGalleryScreen({super.key});

  @override
  State<SuperadminGalleryScreen> createState() => _SuperadminGalleryScreenState();
}

class _SuperadminGalleryScreenState extends State<SuperadminGalleryScreen> {
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

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Galeri Produk Global')),
        body: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Galeri global tidak dapat dimuat: ${friendlyError(snapshot.error!)}'));
            }
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
                        decoration: const InputDecoration(labelText: 'Toko'),
                        items: [
                          const DropdownMenuItem(value: '_all', child: Text('Semua toko')),
                          ...stores.map((s) => DropdownMenuItem(
                                value: s['id'].toString(),
                                child: Text(s['name']?.toString() ?? '-'),
                              )),
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
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search_rounded),
                          hintText: 'Cari produk / SKU...',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: products.isEmpty
                        ? const ListView(
                            children: [
                              SizedBox(height: 140),
                              Center(child: Text('Produk tidak ditemukan.')),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            itemCount: products.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final p = products[i];
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: ListTile(
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ProductGalleryScreen(
                                          productId: p['id'].toString(),
                                          productName: p['name']?.toString() ?? '-',
                                          storeId: p['store_id'].toString(),
                                        ),
                                      ),
                                    );
                                    if (context.mounted) await _refresh();
                                  },
                                  leading: const CircleAvatar(
                                    backgroundColor: Color(0xFFFFECEC),
                                    child: Icon(Icons.photo_library_outlined, color: AppTheme.primary),
                                  ),
                                  title: Text(
                                    p['name']?.toString() ?? '-',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                  subtitle: Text(
                                    '${p['store_name'] ?? '-'} • ${p['sku'] ?? 'tanpa SKU'} • ${p['status']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  trailing: const Icon(Icons.chevron_right_rounded),
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
      );
}
