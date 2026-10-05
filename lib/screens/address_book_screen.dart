import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
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
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => _AddressEditor(address: address),
    );
    if (changed == true && mounted) setState(_reload);
  }

  Future<void> _delete(Map<String, dynamic> address) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus alamat?'),
        content: Text(address['address_line']?.toString() ?? ''),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true) return;
    await ShopRepository.instance.deleteAddress(address['id'] as String);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alamat Tersimpan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Alamat'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return const Center(child: Text('Alamat tidak dapat dimuat.'));
          final rows = snapshot.data ?? [];
          if (rows.isEmpty) return const Center(child: Text('Belum ada alamat tersimpan.'));
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = rows[i];
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
                    color: a['is_default'] == true ? AppTheme.primary : null,
                  ),
                  title: Text('${a['label']} • ${a['recipient_name']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${a['phone']}\n${a['address_line']}, ${a['district']}, ${a['city']}'),
                  isThreeLine: true,
                  trailing: IconButton(
                    onPressed: () => _delete(a),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ),
              );
            },
          );
        },
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
  late final TextEditingController _line;
  late final TextEditingController _postal;
  late final TextEditingController _notes;
  bool _default = false;
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
    _line = TextEditingController(text: a?['address_line']?.toString() ?? '');
    _postal = TextEditingController(text: a?['postal_code']?.toString() ?? '');
    _notes = TextEditingController(text: a?['notes']?.toString() ?? '');
    _default = a?['is_default'] == true;
  }

  @override
  void dispose() {
    for (final c in [_label, _name, _phone, _province, _city, _district, _line, _postal, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ShopRepository.instance;
      if (widget.address == null) {
        await repo.addAddress(
          label: _label.text,
          recipientName: _name.text,
          phone: _phone.text,
          province: _province.text,
          city: _city.text,
          district: _district.text,
          addressLine: _line.text,
          postalCode: _postal.text,
          notes: _notes.text,
          isDefault: _default,
        );
      } else {
        await repo.updateAddress(
          id: widget.address!['id'] as String,
          label: _label.text,
          recipientName: _name.text,
          phone: _phone.text,
          province: _province.text,
          city: _city.text,
          district: _district.text,
          addressLine: _line.text,
          postalCode: _postal.text,
          notes: _notes.text,
          isDefault: _default,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
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
        child: ListView(
          shrinkWrap: true,
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
            TextFormField(controller: _line, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Alamat lengkap'), validator: _required),
            const SizedBox(height: 10),
            TextFormField(controller: _postal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kode pos (opsional)')),
            const SizedBox(height: 10),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Jadikan alamat utama'),
              value: _default,
              onChanged: (v) => setState(() => _default = v),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan Alamat')),
          ],
        ),
      ),
    );
  }
}
