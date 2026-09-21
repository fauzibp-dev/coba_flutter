import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(color: Color(0xFFFFE8E7), shape: BoxShape.circle),
                  child: const Icon(Icons.person_rounded, size: 34, color: AppTheme.primary),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fauzi Bondan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text('Member Shop Mart', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                IconButton(onPressed: () {}, icon: const Icon(Icons.settings_outlined)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Pesanan Saya',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                _QuickAction(icon: Icons.account_balance_wallet_outlined, label: 'Belum Bayar'),
                _QuickAction(icon: Icons.inventory_2_outlined, label: 'Diproses'),
                _QuickAction(icon: Icons.local_shipping_outlined, label: 'Dikirim'),
                _QuickAction(icon: Icons.star_outline_rounded, label: 'Ulasan'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Aktivitas',
            child: Column(
              children: const [
                _MenuTile(icon: Icons.favorite_border_rounded, title: 'Wishlist'),
                _MenuTile(icon: Icons.location_on_outlined, title: 'Alamat Saya'),
                _MenuTile(icon: Icons.local_offer_outlined, title: 'Voucher Saya'),
                _MenuTile(icon: Icons.toll_outlined, title: 'Shop Mart Points'),
                _MenuTile(icon: Icons.notifications_none_rounded, title: 'Notifikasi'),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _section(
            title: 'Bantuan & Informasi',
            child: Column(
              children: const [
                _MenuTile(icon: Icons.support_agent_rounded, title: 'Pusat Bantuan'),
                _MenuTile(icon: Icons.chat_bubble_outline_rounded, title: 'Hubungi Koperasi'),
                _MenuTile(icon: Icons.info_outline_rounded, title: 'Tentang Shop Mart'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Column(
              children: [
                Text('Shop Mart', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 3),
                Text('Koperasi Merah Putih Kerten', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                SizedBox(height: 3),
                Text('Developed by fauzibondanp', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 74,
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFFFF1EF), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppTheme.primary, size: 23),
          ),
          const SizedBox(height: 7),
          Text(label, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, height: 1.2)),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 24,
      leading: Icon(icon, color: AppTheme.textPrimary, size: 22),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title (preview)'))),
    );
  }
}
