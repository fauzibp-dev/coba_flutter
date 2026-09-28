import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/shop_repository.dart';
import 'product_form_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    _future = Future.wait([
      ShopRepository.instance.adminProducts(),
      ShopRepository.instance.adminOrders(),
    ]);
  }

  Future<void> _openProduct([Map<String, dynamic>? product]) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)));
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shop Mart Admin', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Koperasi Merah Putih Kerten', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppTheme.textSecondary)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Produk'), Tab(text: 'Pesanan')],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat admin: ${snapshot.error}'));
          final products = snapshot.data![0] as List<Map<String, dynamic>>;
          final orders = snapshot.data![1] as List<Map<String, dynamic>>;
          return TabBarView(
            controller: _tabs,
            children: [
              _ProductsTab(products: products, onOpen: _openProduct, onReload: () => setState(_reload)),
              _OrdersTab(orders: orders, onReload: () => setState(_reload)),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) => _tabs.index == 0
            ? FloatingActionButton.extended(
                onPressed: () => _openProduct(),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Produk'),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _ProductsTab extends StatelessWidget {
  const _ProductsTab({required this.products, required this.onOpen, required this.onReload});
  final List<Map<String, dynamic>> products;
  final Future<void> Function([Map<String, dynamic>?]) onOpen;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('Belum ada produk. Tekan tombol + Produk.'));
    }
    return RefreshIndicator(
      onRefresh: () async => onReload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final p = products[i];
          final inventory = p['inventory'] as List? ?? [];
          final stock = inventory.fold<int>(0, (sum, e) => sum + (((e as Map)['available_qty'] ?? 0) as num).toInt());
          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
            child: ListTile(
              onTap: () => onOpen(p),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.inventory_2_outlined, color: AppTheme.textSecondary),
              ),
              title: Text(p['name']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${rupiah((p['price'] ?? 0) as num)} • Stok $stock • ${p['status']}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') await onOpen(p);
                  if (value == 'archive') {
                    await ShopRepository.instance.archiveProduct(p['id'] as String);
                    onReload();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrdersTab extends StatelessWidget {
  const _OrdersTab({required this.orders, required this.onReload});
  final List<Map<String, dynamic>> orders;
  final VoidCallback onReload;

  static const statuses = [
    'paid',
    'confirmed',
    'processing',
    'ready_to_ship',
    'shipped',
    'delivered',
    'completed',
    'cancelled',
    'refund_pending',
    'refunded',
  ];

  Future<void> _changeStatus(BuildContext context, Map<String, dynamic> order, String status) async {
    try {
      await ShopRepository.instance.updateOrderStatus(order['id'] as String, status, note: 'Diubah dari Shop Mart Admin');
      onReload();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const Center(child: Text('Belum ada pesanan masuk.'));
    final revenue = orders.where((o) => o['status'] != 'cancelled').fold<num>(0, (sum, o) => sum + ((o['total_amount'] ?? 0) as num));
    final needAction = orders.where((o) => ['pending_payment', 'paid', 'confirmed', 'processing'].contains(o['status'])).length;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _Metric(label: 'Total order', value: '${orders.length}')),
            const SizedBox(width: 8),
            Expanded(child: _Metric(label: 'Perlu diproses', value: '$needAction')),
          ],
        ),
        const SizedBox(height: 8),
        _Metric(label: 'Nilai order non-batal', value: rupiah(revenue)),
        const SizedBox(height: 16),
        ...orders.map((order) {
          final items = order['order_items'] as List? ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(order['order_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))),
                    Text(rupiah((order['total_amount'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary)),
                  ],
                ),
                const SizedBox(height: 5),
                Text('${items.length} item • ${order['payment_method']} • ${order['shipping_method']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: statuses.contains(order['status']) ? order['status'] as String : null,
                  decoration: InputDecoration(labelText: 'Status: ${order['status']}'),
                  items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' ')))).toList(),
                  onChanged: (v) {
                    if (v != null && v != order['status']) _changeStatus(context, order, v);
                  },
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
