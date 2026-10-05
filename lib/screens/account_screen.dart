import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../services/shop_repository.dart';
import '../services/superadmin_repository.dart';
import '../widgets/product_card.dart';
import 'account_security_screen.dart';
import 'address_book_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';
import 'notifications_screen.dart';
import 'product_detail_screen.dart';
import 'superadmin/superadmin_dashboard_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.onAuthChanged});
  final VoidCallback onAuthChanged;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = _load();

  Future<List<dynamic>> _load() async {
    final repo = ShopRepository.instance;
    if (!repo.isSignedIn) return [null, null, false];
    return Future.wait<dynamic>([
      repo.profile(),
      repo.membership(),
      SuperadminRepository.instance.isSuperAdmin(),
    ]);
  }

  Future<void> _login() async {
    final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (ok == true || ShopRepository.instance.isSignedIn) {
      if (mounted) setState(_reload);
      widget.onAuthChanged();
    }
  }

  Future<void> _logout() async {
    await ShopRepository.instance.signOut();
    if (mounted) setState(_reload);
    widget.onAuthChanged();
  }

  Future<void> _editProfile(Map<String, dynamic>? profile) async {
    final name = TextEditingController(text: profile?['full_name']?.toString() ?? '');
    final phone = TextEditingController(text: profile?['phone']?.toString() ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama lengkap')),
            const SizedBox(height: 10),
            TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              await ShopRepository.instance.updateProfile(name: name.text, phone: phone.text);
              if (context.mounted) Navigator.pop(context, true);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _wishlist() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const _WishlistScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!ShopRepository.instance.isSignedIn) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 10),
                const Text('Akun', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 28),
                const Icon(Icons.person_outline_rounded, size: 64, color: AppTheme.textSecondary),
                const SizedBox(height: 14),
                const Text('Masuk untuk menggunakan Shop Mart', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Kelola keranjang, checkout, wishlist, pesanan, dan layanan purnajual dari akunmu.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
                const SizedBox(height: 20),
                FilledButton(onPressed: _login, child: const Text('Masuk / Daftar')),
                const SizedBox(height: 40),
                const Center(child: Text('Shop Mart • Developed by fauzibondanp', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
              ],
            );
          }
          final profile = snapshot.data?[0] as Map<String, dynamic>?;
          final membership = snapshot.data?[1] as Map<String, dynamic>?;
          final isSuperAdmin = snapshot.data?[2] == true;
          final email = ShopRepository.instance.user?.email ?? '';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Akun', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 29, backgroundColor: Color(0xFFFFE5E5), child: Icon(Icons.person_rounded, color: AppTheme.primary, size: 30)),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?['full_name']?.toString().isNotEmpty == true ? profile!['full_name'].toString() : 'Pengguna Shop Mart', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(email, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          if (isSuperAdmin) ...[
                            const SizedBox(height: 5),
                            const Text('Platform • SUPER ADMIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF7F1D1D))),
                          ] else if (membership != null) ...[
                            const SizedBox(height: 5),
                            Text('Pengelola • ${membership['role']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => _editProfile(profile), icon: const Icon(Icons.edit_outlined)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _MenuTile(icon: Icons.favorite_border_rounded, title: 'Wishlist', onTap: _wishlist),
              _MenuTile(
                icon: Icons.location_on_outlined,
                title: 'Alamat tersimpan',
                subtitle: 'Tambah, edit, hapus, dan pilih alamat utama',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressBookScreen())),
              ),
              _MenuTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifikasi',
                subtitle: 'Update pesanan, pengiriman, pembayaran, dan promo',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              _MenuTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Pusat Bantuan',
                subtitle: 'Chat dengan pengelola koperasi',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatScreen())),
              ),
              _MenuTile(
                icon: Icons.security_outlined,
                title: 'Keamanan & Preferensi',
                subtitle: 'Password, email, notifikasi, dan privasi akun',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSecurityScreen())),
              ),
              if (isSuperAdmin) ...[
                const SizedBox(height: 12),
                const Text('Platform', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                _MenuTile(
                  icon: Icons.security_rounded,
                  title: 'Shop Mart Super Admin',
                  subtitle: 'Kontrol seluruh toko, user, katalog, order, promo, fulfillment, retur, dan audit',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SuperadminDashboardScreen())),
                  accent: true,
                ),
              ],
              if (membership != null) ...[
                const SizedBox(height: 12),
                const Text('Pengelola Koperasi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _MenuTile(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Shop Mart Admin',
                  subtitle: 'Produk, stok, order, pembayaran, pengiriman, dan gudang',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen())),
                  accent: true,
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded), label: const Text('Keluar')),
              const SizedBox(height: 28),
              const Center(child: Text('Shop Mart v1.5.0\nDeveloped by fauzibondanp', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.textSecondary))),
            ],
          );
        },
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.onTap, this.subtitle, this.accent = false});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: accent ? const Color(0xFFFFBABA) : AppTheme.border)),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: accent ? AppTheme.primary : AppTheme.textPrimary),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: accent ? AppTheme.primary : AppTheme.textPrimary)),
          subtitle: subtitle == null ? null : Text(subtitle!, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _WishlistScreen extends StatefulWidget {
  const _WishlistScreen();

  @override
  State<_WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<_WishlistScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = ShopRepository.instance.wishlistProducts();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Wishlist')),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data ?? [];
            final products = rows.where((r) => r['products'] is Map).map((r) => Map<String, dynamic>.from(r['products'] as Map)).toList();
            if (products.isEmpty) return const Center(child: Text('Wishlist masih kosong.'));
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.59),
              itemCount: products.length,
              itemBuilder: (_, i) => ProductCard(
                product: products[i],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(productId: products[i]['id'] as String))),
              ),
            );
          },
        ),
      );
}
