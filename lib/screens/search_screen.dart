import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/commerce_repository.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.embedded = false,
    this.initialCategoryId,
    this.initialCategoryName,
  });

  final bool embedded;
  final String? initialCategoryId;
  final String? initialCategoryName;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String? _categoryId;
  String? _categoryName;
  String _sort = 'relevance';
  num? _minPrice;
  num? _maxPrice;
  num? _minRating;
  late Future<List<Map<String, dynamic>>> _future;
  Future<List<String>>? _history;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    _categoryName = widget.initialCategoryName;
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _reload() {
    _future = CommerceRepository.instance.advancedSearch(
      query: _controller.text,
      categoryId: _categoryId,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      minRating: _minRating,
      sort: _sort,
    );
    _history = CommerceRepository.instance.recentSearches();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(_reload);
    });
  }

  Future<void> _openFilters() async {
    final min = TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final max = TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');
    var rating = _minRating;
    final applied = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Filter Produk', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900))),
                  TextButton(
                    onPressed: () {
                      min.clear();
                      max.clear();
                      setSheetState(() => rating = null);
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga minimum'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Harga maksimum'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Rating minimum', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [null, 4.0, 3.0].map((value) {
                  final selected = rating == value;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(value == null ? 'Semua' : '★ ${value.toInt()} ke atas'),
                    onSelected: (_) => setSheetState(() => rating = value),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Terapkan Filter')),
            ],
          ),
        ),
      ),
    );
    if (applied == true && mounted) {
      setState(() {
        _minPrice = num.tryParse(min.text.trim());
        _maxPrice = num.tryParse(max.text.trim());
        _minRating = rating;
        _reload();
      });
    }
    min.dispose();
    max.dispose();
  }

  Widget _searchHistory() {
    if (_controller.text.trim().isNotEmpty || _categoryId != null) return const SizedBox.shrink();
    return FutureBuilder<List<String>>(
      future: _history,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? [];
        if (rows.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Pencarian Terakhir', style: TextStyle(fontWeight: FontWeight.w800))),
                  TextButton(
                    onPressed: () async {
                      await CommerceRepository.instance.clearSearchHistory();
                      if (mounted) setState(_reload);
                    },
                    child: const Text('Hapus'),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: rows
                    .map((q) => ActionChip(
                          label: Text(q),
                          onPressed: () {
                            _controller.text = q;
                            setState(_reload);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeFilters = [_minPrice, _maxPrice, _minRating].where((e) => e != null).length + (_categoryId == null ? 0 : 1);
    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text('Cari Produk', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  ),
                TextField(
                  controller: _controller,
                  autofocus: !widget.embedded && widget.initialCategoryId == null,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: (_) => setState(_reload),
                  decoration: InputDecoration(
                    hintText: 'Cari nama atau deskripsi produk...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              _controller.clear();
                              setState(_reload);
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _sort,
                        isDense: true,
                        decoration: const InputDecoration(labelText: 'Urutkan'),
                        items: const [
                          DropdownMenuItem(value: 'relevance', child: Text('Paling relevan')),
                          DropdownMenuItem(value: 'newest', child: Text('Terbaru')),
                          DropdownMenuItem(value: 'sold', child: Text('Terlaris')),
                          DropdownMenuItem(value: 'rating', child: Text('Rating tertinggi')),
                          DropdownMenuItem(value: 'price_asc', child: Text('Harga terendah')),
                          DropdownMenuItem(value: 'price_desc', child: Text('Harga tertinggi')),
                        ],
                        onChanged: (v) => setState(() {
                          _sort = v ?? 'relevance';
                          _reload();
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: _openFilters,
                      icon: const Icon(Icons.tune_rounded),
                      label: Text(activeFilters == 0 ? 'Filter' : 'Filter ($activeFilters)'),
                    ),
                  ],
                ),
                if (_categoryId != null) ...[
                  const SizedBox(height: 10),
                  InputChip(
                    label: Text(_categoryName ?? 'Kategori'),
                    onDeleted: () {
                      setState(() {
                        _categoryId = null;
                        _categoryName = null;
                        _reload();
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          _searchHistory(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off_outlined, size: 44, color: AppTheme.textSecondary),
                          const SizedBox(height: 10),
                          Text('Pencarian gagal. ${friendlyError(snapshot.error!)}', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: () => setState(_reload), child: const Text('Coba Lagi')),
                        ],
                      ),
                    ),
                  );
                }
                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded, size: 50, color: AppTheme.textSecondary),
                          SizedBox(height: 10),
                          Text('Produk tidak ditemukan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          SizedBox(height: 5),
                          Text('Coba kata kunci, rentang harga, atau filter lain.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(_reload);
                    await _future;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.59,
                    ),
                    itemCount: products.length,
                    itemBuilder: (_, i) => ProductCard(
                      product: products[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: products[i]['id'] as String)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return content;
    return Scaffold(appBar: AppBar(title: Text(_categoryName ?? 'Pencarian')), body: content);
  }
}
