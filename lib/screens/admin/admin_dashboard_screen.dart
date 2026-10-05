import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/shop_repository.dart';
import 'product_form_screen.dart';
import 'voucher_form_screen.dart';

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
    _tabs = TabController(length: 4, vsync: this);
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
      ShopRepository.instance.adminReturns(),
      ShopRepository.instance.vouchers(),
    ]);
  }

  Future<void> _openProduct([Map<String, dynamic>? product]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _openVoucher([Map<String, dynamic>? voucher]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => VoucherFormScreen(voucher: voucher)),
    );
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'Produk'),
            Tab(text: 'Pesanan'),
            Tab(text: 'Retur'),
            Tab(text: 'Voucher'),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat admin: ${friendlyError(snapshot.error!)}'));
          final products = snapshot.data![0] as List<Map<String, dynamic>>;
          final orders = snapshot.data![1] as List<Map<String, dynamic>>;
          final returns = snapshot.data![2] as List<Map<String, dynamic>>;
          final vouchers = snapshot.data![3] as List<Map<String, dynamic>>;
          return TabBarView(
            controller: _tabs,
            children: [
              _ProductsTab(products: products, onOpen: _openProduct, onReload: () => setState(_reload)),
              _OrdersTab(orders: orders, onReload: () => setState(_reload)),
              _ReturnsTab(returns: returns, onReload: () => setState(_reload)),
              _VouchersTab(vouchers: vouchers, onOpen: _openVoucher),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, _) {
          if (_tabs.index == 0) {
            return FloatingActionButton.extended(
              onPressed: () => _openProduct(),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Produk'),
            );
          }
          if (_tabs.index == 3) {
            return FloatingActionButton.extended(
              onPressed: () => _openVoucher(),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Voucher'),
            );
          }
          return const SizedBox.shrink();
        },
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
    if (products.isEmpty) return const Center(child: Text('Belum ada produk. Tekan tombol + Produk.'));
    return RefreshIndicator(
      onRefresh: () async => onReload(),
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, index) {
          final product = products[index];
          final inventory = product['inventory'] as List? ?? [];
          final stock = inventory.fold<int>(0, (sum, raw) => sum + (((raw as Map)['available_qty'] ?? 0) as num).toInt());
          return Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
            child: ListTile(
              onTap: () => onOpen(product),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.inventory_2_outlined, color: AppTheme.textSecondary),
              ),
              title: Text(product['name']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${rupiah((product['price'] ?? 0) as num)} • Stok $stock • ${product['status']}'),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') await onOpen(product);
                  if (value == 'archive') {
                    await ShopRepository.instance.archiveProduct(product['id'] as String);
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
      await ShopRepository.instance.updateOrderStatus(
        order['id'] as String,
        status,
        note: 'Diubah dari Shop Mart Admin',
      );
      onReload();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) return const Center(child: Text('Belum ada pesanan masuk.'));
    final paidValue = orders
        .where((order) => order['payment_status'] == 'paid' && !['cancelled', 'refunded'].contains(order['status']))
        .fold<num>(0, (sum, order) => sum + ((order['total_amount'] ?? 0) as num));
    final needAction = orders.where((order) => ['pending_payment', 'paid', 'confirmed', 'processing', 'ready_to_ship'].contains(order['status'])).length;
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
        _Metric(label: 'Nilai order sudah dibayar', value: rupiah(paidValue)),
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
                  items: statuses.map((status) => DropdownMenuItem(value: status, child: Text(status.replaceAll('_', ' ')))).toList(),
                  onChanged: (value) {
                    if (value != null && value != order['status']) _changeStatus(context, order, value);
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

class _ReturnsTab extends StatelessWidget {
  const _ReturnsTab({required this.returns, required this.onReload});
  final List<Map<String, dynamic>> returns;
  final VoidCallback onReload;

  static const statuses = ['approved', 'rejected', 'received', 'closed'];

  Future<void> _change(BuildContext context, Map<String, dynamic> row, String status) async {
    try {
      await ShopRepository.instance.updateReturnStatus(row['id'] as String, status);
      onReload();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (returns.isEmpty) return const Center(child: Text('Belum ada pengajuan retur.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: returns.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (_, index) {
        final row = returns[index];
        final order = row['orders'] is Map ? Map<String, dynamic>.from(row['orders'] as Map) : <String, dynamic>{};
        return Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(order['order_number']?.toString() ?? 'Retur', style: const TextStyle(fontWeight: FontWeight.w900))),
                  Text(row['status']?.toString().replaceAll('_', ' ') ?? '-', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Alasan: ${row['reason'] ?? '-'}'),
              if (row['description']?.toString().trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(row['description'].toString(), style: const TextStyle(color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Ubah status retur'),
                items: statuses.map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                onChanged: (value) {
                  if (value != null && value != row['status']) _change(context, row, value);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VouchersTab extends StatelessWidget {
  const _VouchersTab({required this.vouchers, required this.onOpen});
  final List<Map<String, dynamic>> vouchers;
  final Future<void> Function([Map<String, dynamic>?]) onOpen;

  @override
  Widget build(BuildContext context) {
    if (vouchers.isEmpty) return const Center(child: Text('Belum ada voucher. Tekan tombol + Voucher.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vouchers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (_, index) {
        final voucher = vouchers[index];
        final value = voucher['discount_type'] == 'percentage'
            ? '${((voucher['discount_value'] ?? 0) as num).toInt()}%'
            : rupiah((voucher['discount_value'] ?? 0) as num);
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
          child: ListTile(
            onTap: () => onOpen(voucher),
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFE5E5), child: Icon(Icons.local_offer_outlined, color: AppTheme.primary)),
            title: Text('${voucher['code']} • ${voucher['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('$value • Min ${rupiah((voucher['minimum_purchase'] ?? 0) as num)} • ${voucher['is_active'] == true ? 'aktif' : 'nonaktif'}'),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        );
      },
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
