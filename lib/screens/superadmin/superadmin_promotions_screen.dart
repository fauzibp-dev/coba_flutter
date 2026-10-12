import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_repository.dart';

class SuperadminPromotionsScreen extends StatefulWidget {
  const SuperadminPromotionsScreen({super.key});

  @override
  State<SuperadminPromotionsScreen> createState() => _SuperadminPromotionsScreenState();
}

class _SuperadminPromotionsScreenState extends State<SuperadminPromotionsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String? _storeId;
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
      SuperadminRepository.instance.vouchers(storeId: _storeId),
      SuperadminRepository.instance.banners(storeId: _storeId),
      SuperadminRepository.instance.stores(),
    ]);
  }

  Future<void> _editVoucher(Map<String, dynamic>? voucher, List<Map<String, dynamic>> stores) async {
    if (stores.isEmpty) return;
    var storeId = voucher?['store_id']?.toString() ?? _storeId ?? stores.first['id'].toString();
    final code = TextEditingController(text: voucher?['code']?.toString() ?? '');
    final title = TextEditingController(text: voucher?['title']?.toString() ?? '');
    final value = TextEditingController(text: voucher?['discount_value']?.toString() ?? '');
    final minimum = TextEditingController(text: voucher?['minimum_purchase']?.toString() ?? '0');
    final maximum = TextEditingController(text: voucher?['maximum_discount']?.toString() ?? '');
    final usageLimit = TextEditingController(text: voucher?['usage_limit']?.toString() ?? '');
    final usagePerUser = TextEditingController(text: voucher?['usage_per_user']?.toString() ?? '1');
    var type = voucher?['discount_type']?.toString() ?? 'percentage';
    var active = voucher?['is_active'] as bool? ?? true;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          title: Text(voucher == null ? 'Tambah Voucher' : 'Edit Voucher'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 80 < 480 ? MediaQuery.sizeOf(context).width - 80 : 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: storeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Toko *'),
                    items: stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: voucher != null || saving ? null : (v) => setDialogState(() => storeId = v ?? storeId),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Kode *'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul *'))),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Jenis diskon'),
                    items: const [
                      DropdownMenuItem(value: 'percentage', child: Text('Persentase')),
                      DropdownMenuItem(value: 'fixed', child: Text('Nominal tetap')),
                    ],
                    onChanged: saving ? null : (v) => setDialogState(() => type = v ?? type),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nilai diskon *'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: minimum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Minimum belanja'))),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: TextField(controller: maximum, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Maks. diskon'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: usageLimit, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit total'))),
                  ]),
                  const SizedBox(height: 10),
                  TextField(controller: usagePerUser, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit per pengguna')),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Voucher aktif'), value: active, onChanged: saving ? null : (v) => setDialogState(() => active = v)),
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
                      final discount = num.tryParse(value.text.replaceAll(',', '.'));
                      final min = num.tryParse(minimum.text.replaceAll(',', '.')) ?? 0;
                      final max = maximum.text.trim().isEmpty ? null : num.tryParse(maximum.text.replaceAll(',', '.'));
                      final totalLimit = usageLimit.text.trim().isEmpty ? null : int.tryParse(usageLimit.text.trim());
                      final perUser = int.tryParse(usagePerUser.text.trim()) ?? 1;
                      if (code.text.trim().isEmpty || title.text.trim().isEmpty || discount == null || discount <= 0) return;
                      setDialogState(() => saving = true);
                      try {
                        await SuperadminRepository.instance.saveVoucher(
                          id: voucher?['id']?.toString(),
                          storeId: storeId,
                          code: code.text,
                          title: title.text,
                          discountType: type,
                          discountValue: discount,
                          minimumPurchase: min,
                          maximumDiscount: max,
                          usageLimit: totalLimit,
                          usagePerUser: perUser,
                          startsAt: DateTime.tryParse(voucher?['starts_at']?.toString() ?? ''),
                          endsAt: DateTime.tryParse(voucher?['ends_at']?.toString() ?? ''),
                          isActive: active,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                      }
                    },
              child: Text(saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );

    code.dispose();
    title.dispose();
    value.dispose();
    minimum.dispose();
    maximum.dispose();
    usageLimit.dispose();
    usagePerUser.dispose();
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _editBanner(Map<String, dynamic>? banner, List<Map<String, dynamic>> stores) async {
    if (stores.isEmpty) return;
    var storeId = banner?['store_id']?.toString() ?? _storeId ?? stores.first['id'].toString();
    final title = TextEditingController(text: banner?['title']?.toString() ?? '');
    final subtitle = TextEditingController(text: banner?['subtitle']?.toString() ?? '');
    final image = TextEditingController(text: banner?['image_url']?.toString() ?? '');
    final targetType = TextEditingController(text: banner?['target_type']?.toString() ?? '');
    final targetId = TextEditingController(text: banner?['target_id']?.toString() ?? '');
    final sort = TextEditingController(text: banner?['sort_order']?.toString() ?? '0');
    var active = banner?['is_active'] as bool? ?? true;
    var saving = false;

    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          title: Text(banner == null ? 'Tambah Banner' : 'Edit Banner'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width - 80 < 480 ? MediaQuery.sizeOf(context).width - 80 : 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: storeId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Toko *'),
                    items: stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: banner != null || saving ? null : (v) => setDialogState(() => storeId = v ?? storeId),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul *')),
                  const SizedBox(height: 10),
                  TextField(controller: subtitle, decoration: const InputDecoration(labelText: 'Subtitle')),
                  const SizedBox(height: 10),
                  TextField(controller: image, decoration: const InputDecoration(labelText: 'Image URL')),
                  const SizedBox(height: 10),
                  TextField(controller: targetType, decoration: const InputDecoration(labelText: 'Target type')),
                  const SizedBox(height: 10),
                  TextField(controller: targetId, decoration: const InputDecoration(labelText: 'Target UUID')),
                  const SizedBox(height: 10),
                  TextField(controller: sort, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Urutan')),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Banner aktif'), value: active, onChanged: saving ? null : (v) => setDialogState(() => active = v)),
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
                      if (title.text.trim().isEmpty) return;
                      setDialogState(() => saving = true);
                      try {
                        await SuperadminRepository.instance.saveBanner(
                          id: banner?['id']?.toString(),
                          storeId: storeId,
                          title: title.text,
                          subtitle: subtitle.text,
                          imageUrl: image.text,
                          targetType: targetType.text,
                          targetId: targetId.text.trim().isEmpty ? null : targetId.text.trim(),
                          sortOrder: int.tryParse(sort.text.trim()) ?? 0,
                          startsAt: DateTime.tryParse(banner?['starts_at']?.toString() ?? ''),
                          endsAt: DateTime.tryParse(banner?['ends_at']?.toString() ?? ''),
                          isActive: active,
                        );
                        if (context.mounted) Navigator.pop(context, true);
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                      }
                    },
              child: Text(saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    subtitle.dispose();
    image.dispose();
    targetType.dispose();
    targetId.dispose();
    sort.dispose();
    if (changed == true && mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promo & Banner', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(controller: _tabs, tabs: const [Tab(text: 'Voucher'), Tab(text: 'Banner')]),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Gagal memuat promo: ${friendlyError(snapshot.error!)}'));
          final vouchers = snapshot.data![0] as List<Map<String, dynamic>>;
          final banners = snapshot.data![1] as List<Map<String, dynamic>>;
          final stores = snapshot.data![2] as List<Map<String, dynamic>>;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: DropdownButtonFormField<String>(
                  initialValue: _storeId ?? '_all',
                  decoration: const InputDecoration(labelText: 'Filter toko'),
                  items: [
                    const DropdownMenuItem(value: '_all', child: Text('Semua toko')),
                    ...stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-'))),
                  ],
                  onChanged: (v) => setState(() {
                    _storeId = v == '_all' ? null : v;
                    _reload();
                  }),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _VoucherList(vouchers: vouchers, onEdit: (v) => _editVoucher(v, stores)),
                    _BannerList(banners: banners, onEdit: (v) => _editBanner(v, stores)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabs,
        builder: (_, __) => FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            final stores = snapshot.data == null ? <Map<String, dynamic>>[] : snapshot.data![2] as List<Map<String, dynamic>>;
            return FloatingActionButton.extended(
              onPressed: stores.isEmpty ? null : () => _tabs.index == 0 ? _editVoucher(null, stores) : _editBanner(null, stores),
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(_tabs.index == 0 ? 'Voucher' : 'Banner'),
            );
          },
        ),
      ),
    );
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList({required this.vouchers, required this.onEdit});
  final List<Map<String, dynamic>> vouchers;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    if (vouchers.isEmpty) return const Center(child: Text('Belum ada voucher.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: vouchers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final v = vouchers[i];
        final suffix = v['discount_type'] == 'percentage' ? '%' : '';
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
          child: ListTile(
            onTap: () => onEdit(v),
            leading: const CircleAvatar(child: Icon(Icons.local_offer_outlined)),
            title: Text('${v['code']} • ${v['title']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${v['store_name']} • diskon ${v['discount_value']}$suffix • min ${rupiah((v['minimum_purchase'] ?? 0) as num)} • ${v['is_active'] == true ? 'aktif' : 'nonaktif'}', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.edit_outlined),
          ),
        );
      },
    );
  }
}

class _BannerList extends StatelessWidget {
  const _BannerList({required this.banners, required this.onEdit});
  final List<Map<String, dynamic>> banners;
  final ValueChanged<Map<String, dynamic>> onEdit;

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const Center(child: Text('Belum ada banner.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: banners.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final b = banners[i];
        return Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
          child: ListTile(
            onTap: () => onEdit(b),
            leading: const CircleAvatar(child: Icon(Icons.campaign_outlined)),
            title: Text(b['title']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${b['store_name']} • urutan ${b['sort_order'] ?? 0} • ${b['is_active'] == true ? 'aktif' : 'nonaktif'}', style: const TextStyle(fontSize: 12)),
            trailing: const Icon(Icons.edit_outlined),
          ),
        );
      },
    );
  }
}
