import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminUsersScreen extends StatefulWidget {
  const SuperadminUsersScreen({super.key});

  @override
  State<SuperadminUsersScreen> createState() => _SuperadminUsersScreenState();
}

class _SuperadminUsersScreenState extends State<SuperadminUsersScreen> {
  final _search = TextEditingController();
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
      SuperadminRepository.instance.users(search: _search.text),
      SuperadminRepository.instance.stores(),
    ]);
  }

  Future<void> _manage(Map<String, dynamic> user, List<Map<String, dynamic>> stores) async {
    final memberships = (user['memberships'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    String? storeId = stores.isEmpty ? null : stores.first['id']?.toString();
    var role = 'staff';
    var enabled = false;
    var superadmin = user['is_super_admin'] == true;
    var saving = false;

    void syncMembership() {
      final existing = memberships.where((m) => m['store_id']?.toString() == storeId).toList();
      if (existing.isNotEmpty) {
        enabled = true;
        role = existing.first['role']?.toString() ?? 'staff';
      } else {
        enabled = false;
        role = 'staff';
      }
    }

    syncMembership();

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Hak Akses Pengguna'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['full_name']?.toString().isNotEmpty == true ? user['full_name'].toString() : 'Pengguna', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  Text(user['email']?.toString() ?? '-', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10)),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Platform Super Admin', style: TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: const Text('Akses global seluruh toko dan modul sensitif.'),
                      value: superadmin,
                      onChanged: saving ? null : (v) => setDialogState(() => superadmin = v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Akses toko', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (stores.isEmpty)
                    const Text('Belum ada toko.')
                  else ...[
                    DropdownButtonFormField<String>(
                      initialValue: storeId,
                      decoration: const InputDecoration(labelText: 'Toko'),
                      items: stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-'))).toList(),
                      onChanged: saving
                          ? null
                          : (v) => setDialogState(() {
                                storeId = v;
                                syncMembership();
                              }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Terdaftar sebagai pengelola'),
                      value: enabled,
                      onChanged: saving ? null : (v) => setDialogState(() => enabled = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: role,
                      decoration: const InputDecoration(labelText: 'Role toko'),
                      items: const [
                        DropdownMenuItem(value: 'owner', child: Text('Owner')),
                        DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        DropdownMenuItem(value: 'staff', child: Text('Staff')),
                      ],
                      onChanged: !enabled || saving ? null : (v) => setDialogState(() => role = v ?? 'staff'),
                    ),
                  ],
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
                      setDialogState(() => saving = true);
                      try {
                        final currentlySuper = user['is_super_admin'] == true;
                        if (currentlySuper != superadmin) {
                          await SuperadminRepository.instance.setPlatformAdmin(userId: user['user_id'].toString(), enabled: superadmin);
                        }
                        if (storeId != null) {
                          await SuperadminRepository.instance.setStoreMember(
                            userId: user['user_id'].toString(),
                            storeId: storeId!,
                            role: role,
                            enabled: enabled,
                          );
                        }
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                      }
                    },
              child: Text(saving ? 'Menyimpan...' : 'Simpan Akses'),
            ),
          ],
        ),
      ),
    );
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna & Hak Akses', style: TextStyle(fontWeight: FontWeight.w900))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(_reload),
              decoration: InputDecoration(
                hintText: 'Cari nama atau email',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: () => setState(_reload)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Gagal memuat pengguna: ${friendlyError(snapshot.error!)}'));
                final users = snapshot.data![0] as List<Map<String, dynamic>>;
                final stores = snapshot.data![1] as List<Map<String, dynamic>>;
                if (users.isEmpty) return const Center(child: Text('Pengguna tidak ditemukan.'));
                return RefreshIndicator(
                  onRefresh: () async => setState(_reload),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final u = users[i];
                      final memberships = (u['memberships'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
                      return Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u['full_name']?.toString().isNotEmpty == true ? u['full_name'].toString() : 'Pengguna Shop Mart', style: const TextStyle(fontWeight: FontWeight.w800)),
                                      Text(u['email']?.toString() ?? '-', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                IconButton(onPressed: () => _manage(u, stores), icon: const Icon(Icons.admin_panel_settings_outlined)),
                              ],
                            ),
                            if (u['is_super_admin'] == true) ...[
                              const SizedBox(height: 8),
                              const Chip(label: Text('SUPER ADMIN'), avatar: Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.primary)),
                            ],
                            if (memberships.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: memberships.map((m) => Chip(label: Text('${m['store_name']} • ${m['role']}'))).toList(),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
