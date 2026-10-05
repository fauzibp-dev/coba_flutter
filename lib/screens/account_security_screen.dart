import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/commerce_repository.dart';
import '../services/shop_repository.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  late Future<Map<String, dynamic>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = CommerceRepository.instance.notificationPreferences();

  Future<void> _savePrefs(Map<String, dynamic> prefs, String key, bool value) async {
    setState(() => _saving = true);
    try {
      await CommerceRepository.instance.updateNotificationPreferences({
        'order_updates': key == 'order_updates' ? value : prefs['order_updates'] == true,
        'chat_messages': key == 'chat_messages' ? value : prefs['chat_messages'] == true,
        'promotions': key == 'promotions' ? value : prefs['promotions'] == true,
        'push_enabled': key == 'push_enabled' ? value : prefs['push_enabled'] == true,
        'email_enabled': key == 'email_enabled' ? value : prefs['email_enabled'] == true,
      });
      if (mounted) setState(_reload);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = ShopRepository.instance.user?.email;
    if (email == null) return;
    try {
      await CommerceRepository.instance.sendPasswordReset(email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Link reset password dikirim ke $email.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Password'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password baru', helperText: 'Minimal 8 karakter'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.length >= 8),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await CommerceRepository.instance.updatePassword(controller.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password berhasil diperbarui.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    controller.dispose();
  }

  Future<void> _changeEmail() async {
    final controller = TextEditingController(text: ShopRepository.instance.user?.email ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ganti Email'),
        content: TextField(controller: controller, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email baru')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.contains('@')), child: const Text('Kirim Konfirmasi')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await CommerceRepository.instance.updateEmail(controller.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perubahan email dikirim. Ikuti konfirmasi dari Supabase Auth.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    controller.dispose();
  }

  Future<void> _requestDeletion() async {
    final reason = TextEditingController();
    var checked = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajukan Penghapusan Akun'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Permintaan akan masuk ke antrean privasi. Data transaksi yang wajib disimpan dapat dianonimkan sesuai kebijakan operasional.'),
              const SizedBox(height: 12),
              TextField(controller: reason, maxLines: 2, decoration: const InputDecoration(labelText: 'Alasan (opsional)')),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: checked,
                onChanged: (v) => setDialogState(() => checked = v == true),
                title: const Text('Saya memahami akun akan dinonaktifkan/dihapus setelah diproses.'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: checked ? () => Navigator.pop(context, true) : null, child: const Text('Ajukan')),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await CommerceRepository.instance.requestAccountDeletion(reason: reason.text);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permintaan penghapusan akun sudah tercatat.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    reason.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Keamanan & Preferensi')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat preferensi: ${friendlyError(snapshot.error!)}'));
          final prefs = snapshot.data ?? const <String, dynamic>{};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Keamanan Akun', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              _Tile(icon: Icons.password_rounded, title: 'Ganti password', subtitle: 'Perbarui password sesi aktif', onTap: _changePassword),
              _Tile(icon: Icons.mark_email_read_outlined, title: 'Kirim link reset password', subtitle: ShopRepository.instance.user?.email ?? '-', onTap: _resetPassword),
              _Tile(icon: Icons.alternate_email_rounded, title: 'Ganti email', subtitle: 'Memerlukan konfirmasi email baru', onTap: _changeEmail),
              const SizedBox(height: 18),
              const Text('Notifikasi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              _Switch(title: 'Update pesanan', value: prefs['order_updates'] == true, enabled: !_saving, onChanged: (v) => _savePrefs(prefs, 'order_updates', v)),
              _Switch(title: 'Pesan customer service', value: prefs['chat_messages'] == true, enabled: !_saving, onChanged: (v) => _savePrefs(prefs, 'chat_messages', v)),
              _Switch(title: 'Promo & campaign', value: prefs['promotions'] == true, enabled: !_saving, onChanged: (v) => _savePrefs(prefs, 'promotions', v)),
              _Switch(title: 'Push notification', subtitle: 'Aktif saat provider push/device token sudah dikonfigurasi.', value: prefs['push_enabled'] == true, enabled: !_saving, onChanged: (v) => _savePrefs(prefs, 'push_enabled', v)),
              _Switch(title: 'Email notification', value: prefs['email_enabled'] == true, enabled: !_saving, onChanged: (v) => _savePrefs(prefs, 'email_enabled', v)),
              const SizedBox(height: 18),
              const Text('Privasi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              _Tile(icon: Icons.delete_forever_outlined, title: 'Ajukan penghapusan akun', subtitle: 'Masuk antrean privasi & audit', onTap: _requestDeletion, danger: true),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.danger = false});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: danger ? AppTheme.error : AppTheme.primary),
          title: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: danger ? AppTheme.error : null)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _Switch extends StatelessWidget {
  const _Switch({required this.title, required this.value, required this.onChanged, required this.enabled, this.subtitle});
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
        child: SwitchListTile(
          value: value,
          onChanged: enabled ? onChanged : null,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: subtitle == null ? null : Text(subtitle!),
        ),
      );
}
