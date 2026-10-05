import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';

class AddressScreen extends StatefulWidget {
  const AddressScreen({super.key});

  @override
  State<AddressScreen> createState() => _AddressScreenState();
}

class _AddressScreenState extends State<AddressScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _future = ShopRepository.instance.addresses();

  Future<void> _open([Map<String, dynamic>? address]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddressEditor(address: address),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _delete(Map<String, dynamic> address) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus alamat?'),
        content: Text('Alamat ${address['label'] ?? ''} akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (yes != true) return;
    await ShopRepository.instance.deleteAddress(address['id'] as String);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Tersimpan')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Gagal memuat alamat: ${friendlyError(snapshot.error!)}'));
          }
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on_outlined, size: 54, color: AppTheme.textSecondary),
                    SizedBox(height: 12),
                    Text('Belum ada alamat', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    SizedBox(height: 5),
                    Text('Tambahkan alamat untuk mempercepat checkout.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary)),
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
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                final a = rows[index];
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: ListTile(
                    onTap: () => _open(a),
                    leading: Icon(
                      a['is_default'] == true ? Icons.home_rounded : Icons.location_on_outlined,
                      color: a['is_default'] == true ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                    title: Row(
                      children: [
                        Expanded(child: Text(a['label']?.toString() ?? 'Alamat', style: const TextStyle(fontWeight: FontWeight.w800))),
                        if (a['is_default'] == true)
                          const Text('Utama', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    subtitle: Text(
                      '${a['recipient_name']} • ${a['phone']}\n${a['address_line']}, ${a['district']}, ${a['city']}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') _open(a);
                        if (value == 'delete') _delete(a);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Hapus')),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Alamat'),
      ),
    );
  }
}

class _AddressEditor extends StatefulWidget {
  const _AddressEditor({this.address});
  final Map<String, dynamic>? address;

  @override
  State<_AddressEditor> createState() => _AddressEditorState();
}

class _AddressEditorState extends State<_AddressEditor> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _province;
  late final TextEditingController _city;
  late final TextEditingController _district;
  late final TextEditingController _address;
  late final TextEditingController _postal;
  late final TextEditingController _notes;
  late bool _defaultAddress;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.address;
    _label = TextEditingController(text: a?['label']?.toString() ?? 'Rumah');
    _name = TextEditingController(text: a?['recipient_name']?.toString() ?? '');
    _phone = TextEditingController(text: a?['phone']?.toString() ?? '');
    _province = TextEditingController(text: a?['province']?.toString() ?? 'Jawa Tengah');
    _city = TextEditingController(text: a?['city']?.toString() ?? 'Surakarta');
    _district = TextEditingController(text: a?['district']?.toString() ?? 'Laweyan');
    _address = TextEditingController(text: a?['address_line']?.toString() ?? '');
    _postal = TextEditingController(text: a?['postal_code']?.toString() ?? '');
    _notes = TextEditingController(text: a?['notes']?.toString() ?? '');
    _defaultAddress = a?['is_default'] == true || a == null;
  }

  @override
  void dispose() {
    for (final controller in [_label, _name, _phone, _province, _city, _district, _address, _postal, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  static String? _required(String? value) => value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ShopRepository.instance.saveAddress(
        id: widget.address?['id'] as String?,
        label: _label.text,
        recipientName: _name.text,
        phone: _phone.text,
        province: _province.text,
        city: _city.text,
        district: _district.text,
        addressLine: _address.text,
        postalCode: _postal.text,
        notes: _notes.text,
        isDefault: _defaultAddress,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _key,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.address == null ? 'Tambah Alamat' : 'Edit Alamat', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextFormField(controller: _label, decoration: const InputDecoration(labelText: 'Label'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nama penerima'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor HP'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _province, decoration: const InputDecoration(labelText: 'Provinsi'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'Kota/Kabupaten'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _district, decoration: const InputDecoration(labelText: 'Kecamatan'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _address, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Alamat lengkap'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _postal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kode pos (opsional)')),
              const SizedBox(height: 10),
              TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Jadikan alamat utama'),
                value: _defaultAddress,
                onChanged: (value) => setState(() => _defaultAddress = value),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan Alamat')),
            ],
          ),
        ),
      ),
    );
  }
}
