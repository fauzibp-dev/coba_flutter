import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/product_gallery_repository.dart';

class ProductGalleryScreen extends StatefulWidget {
  const ProductGalleryScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.storeId,
  });

  final String productId;
  final String productName;
  final String? storeId;

  @override
  State<ProductGalleryScreen> createState() => _ProductGalleryScreenState();
}

class _ProductGalleryScreenState extends State<ProductGalleryScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = ProductGalleryRepository.instance.images(widget.productId);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _addImages() async {
    if (_busy) return;
    final files = await ImagePicker().pickMultiImage(
      imageQuality: 84,
      maxWidth: 1800,
    );
    if (files.isEmpty || !mounted) return;
    setState(() => _busy = true);
    var uploaded = 0;
    try {
      for (final file in files.take(8)) {
        await ProductGalleryRepository.instance.upload(
          productId: widget.productId,
          storeId: widget.storeId,
          file: file,
        );
        uploaded++;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$uploaded gambar berhasil ditambahkan.')),
        );
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
        await _refresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setPrimary(Map<String, dynamic> image) async {
    if (_busy || image['is_primary'] == true) return;
    setState(() => _busy = true);
    try {
      await ProductGalleryRepository.instance.setPrimary(
        productId: widget.productId,
        imageId: image['id'].toString(),
      );
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> image) async {
    if (_busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus gambar?'),
        content: const Text('Gambar akan dihapus dari galeri produk dan Storage jika file masih tersedia.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ProductGalleryRepository.instance.delete(
        productId: widget.productId,
        image: image,
      );
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reorder(
    List<Map<String, dynamic>> current,
    int oldIndex,
    int newIndex,
  ) async {
    if (_busy) return;
    if (newIndex > oldIndex) newIndex--;
    final next = [...current];
    final item = next.removeAt(oldIndex);
    next.insert(newIndex, item);
    setState(() {
      _future = Future.value(next);
      _busy = true;
    });
    try {
      await ProductGalleryRepository.instance.reorder(
        widget.productId,
        next.map((e) => e['id'].toString()).toList(),
      );
      if (mounted) _future = Future.value(next);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        await _refresh();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Galeri Produk'),
              Text(
                widget.productName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Tambah gambar',
              onPressed: _busy ? null : _addImages,
              icon: const Icon(Icons.add_photo_alternate_outlined),
            ),
          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Galeri tidak dapat dimuat: ${friendlyError(snapshot.error!)}', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: _refresh, child: const Text('Coba lagi')),
                    ],
                  ),
                ),
              );
            }
            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            if (rows.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 58, color: AppTheme.textSecondary),
                      const SizedBox(height: 12),
                      const Text('Belum ada gambar produk', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text(
                        'Tambahkan beberapa foto, tentukan foto utama, lalu atur urutannya.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : _addImages,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Tambah Gambar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF8F8),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Text(
                    '${rows.length} gambar • tahan ikon drag untuk mengubah urutan • gambar utama dipakai pada kartu katalog.',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      onReorder: (oldIndex, newIndex) => _reorder(rows, oldIndex, newIndex),
                      itemBuilder: (context, index) {
                        final image = rows[index];
                        final primary = image['is_primary'] == true;
                        return Container(
                          key: ValueKey(image['id']),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primary ? const Color(0xFFFFBABA) : AppTheme.border,
                              width: primary ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: Image.network(
                                  image['image_url']?.toString() ?? '',
                                  width: 82,
                                  height: 82,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 82,
                                    height: 82,
                                    color: const Color(0xFFF1F1F1),
                                    child: const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text('Foto ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                        if (primary) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFECEC),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: const Text(
                                              'UTAMA',
                                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.primary),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        TextButton.icon(
                                          onPressed: primary || _busy ? null : () => _setPrimary(image),
                                          icon: const Icon(Icons.star_outline_rounded, size: 17),
                                          label: const Text('Jadikan utama'),
                                        ),
                                        TextButton.icon(
                                          onPressed: _busy ? null : () => _delete(image),
                                          icon: const Icon(Icons.delete_outline_rounded, size: 17),
                                          label: const Text('Hapus'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle_rounded, color: AppTheme.textSecondary),
                                ),
                              ),
                            ],
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
        floatingActionButton: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (_, snapshot) => snapshot.data?.isNotEmpty == true
              ? FloatingActionButton.extended(
                  onPressed: _busy ? null : _addImages,
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Gambar'),
                )
              : const SizedBox.shrink(),
        ),
      );
}
