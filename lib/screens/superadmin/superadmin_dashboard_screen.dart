import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';
import 'superadmin_audit_screen.dart';
import 'superadmin_categories_screen.dart';
import 'superadmin_orders_screen.dart';
import 'superadmin_products_screen.dart';
import 'superadmin_promotions_screen.dart';
import 'superadmin_returns_screen.dart';
import 'superadmin_stores_screen.dart';
import 'superadmin_users_screen.dart';

class SuperadminDashboardScreen extends StatefulWidget {
  const SuperadminDashboardScreen({super.key});

  @override
  State<SuperadminDashboardScreen> createState() => _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen> {
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = SuperadminRepository.instance.dashboard();

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Shop Mart Super Admin', style: TextStyle(fontWeight: FontWeight.w900)),
            Text('Kontrol platform dan seluruh toko', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
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
                    const Icon(Icons.lock_outline_rounded, size: 52, color: AppTheme.textSecondary),
                    const SizedBox(height: 12),
                    Text('Super Admin tidak dapat dimuat.\n${friendlyError(snapshot.error!)}', textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(onPressed: () => setState(_reload), child: const Text('Coba lagi')),
                  ],
                ),
              ),
            );
          }
          final d = snapshot.data ?? const <String, dynamic>{};
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFF1F1F1F), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Platform Control Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Akses global untuk toko, akun pengelola, kategori, katalog, order, promo, retur, dan audit.',
                        style: TextStyle(color: Colors.white.withValues(alpha: .78), height: 1.35, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.55,
                  children: [
                    _Metric(label: 'Toko aktif', value: '${d['active_stores'] ?? 0}/${d['stores'] ?? 0}', icon: Icons.storefront_outlined),
                    _Metric(label: 'Pengguna', value: '${d['users'] ?? 0}', icon: Icons.people_outline_rounded),
                    _Metric(label: 'Produk aktif', value: '${d['active_products'] ?? 0}/${d['products'] ?? 0}', icon: Icons.inventory_2_outlined),
                    _Metric(label: 'Perlu diproses', value: '${d['pending_orders'] ?? 0}', icon: Icons.receipt_long_outlined),
                    _Metric(label: 'Revenue paid', value: rupiah((d['paid_revenue'] ?? 0) as num), icon: Icons.payments_outlined),
                    _Metric(label: 'Stok rendah', value: '${d['low_stock'] ?? 0}', icon: Icons.warning_amber_rounded),
                  ],
                ),
                const SizedBox(height: 18),
                const Text('Manajemen Platform', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.store_mall_directory_outlined,
                  title: 'Toko & Koperasi',
                  subtitle: 'Buat, edit, aktif/nonaktifkan toko',
                  onTap: () => _open(const SuperadminStoresScreen()),
                ),
                _ActionTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Pengguna & Hak Akses',
                  subtitle: 'Owner, admin, staff, dan Super Admin',
                  onTap: () => _open(const SuperadminUsersScreen()),
                ),
                _ActionTile(
                  icon: Icons.category_outlined,
                  title: 'Kategori Global',
                  subtitle: 'Atur kategori, hierarki, urutan, dan status per toko',
                  onTap: () => _open(const SuperadminCategoriesScreen()),
                ),
                _ActionTile(
                  icon: Icons.inventory_2_outlined,
                  title: 'Katalog Global',
                  subtitle: 'Edit produk, harga, status, stok, kategori, dan gambar',
                  onTap: () => _open(const SuperadminProductsScreen()),
                ),
                _ActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Pesanan Global',
                  subtitle: 'Pantau dan proses order seluruh toko',
                  onTap: () => _open(const SuperadminOrdersScreen()),
                ),
                _ActionTile(
                  icon: Icons.campaign_outlined,
                  title: 'Promo & Banner',
                  subtitle: 'Voucher dan konten promosi per toko',
                  onTap: () => _open(const SuperadminPromotionsScreen()),
                ),
                _ActionTile(
                  icon: Icons.assignment_return_outlined,
                  title: 'Retur & After Sales',
                  subtitle: 'Review status permintaan retur',
                  onTap: () => _open(const SuperadminReturnsScreen()),
                ),
                _ActionTile(
                  icon: Icons.history_rounded,
                  title: 'Audit Log',
                  subtitle: 'Jejak perubahan sensitif seluruh platform',
                  onTap: () => _open(const SuperadminAuditScreen()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: const Color(0xFFFFECEC), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
