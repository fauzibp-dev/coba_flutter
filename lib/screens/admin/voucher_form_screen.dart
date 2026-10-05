import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/shop_repository.dart';

class VoucherFormScreen extends StatefulWidget {
  const VoucherFormScreen({super.key, this.voucher});
  final Map<String, dynamic>? voucher;

  @override
  State<VoucherFormScreen> createState() => _VoucherFormScreenState();
}

class _VoucherFormScreenState extends State<VoucherFormScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _code;
  late final TextEditingController _title;
  late final TextEditingController _value;
  late final TextEditingController _minimum;
  late final TextEditingController _maximum;
  late final TextEditingController _usageLimit;
  late final TextEditingController _perUser;
  late String _type;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final voucher = widget.voucher;
    _code = TextEditingController(text: voucher?['code']?.toString() ?? '');
    _title = TextEditingController(text: voucher?['title']?.toString() ?? '');
    _value = TextEditingController(text: voucher == null ? '' : ((voucher['discount_value'] ?? 0) as num).toInt().toString());
    _minimum = TextEditingController(text: voucher == null ? '0' : ((voucher['minimum_purchase'] ?? 0) as num).toInt().toString());
    _maximum = TextEditingController(text: voucher?['maximum_discount'] == null ? '' : ((voucher!['maximum_discount']) as num).toInt().toString());
    _usageLimit = TextEditingController(text: voucher?['usage_limit']?.toString() ?? '');
    _perUser = TextEditingController(text: voucher?['usage_per_user']?.toString() ?? '1');
    _type = voucher?['discount_type']?.toString() ?? 'fixed';
    _active = voucher?['is_active'] != false;
  }

  @override
  void dispose() {
    for (final controller in [_code, _title, _value, _minimum, _maximum, _usageLimit, _perUser]) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _int(String value) => int.tryParse(value.replaceAll('.', '').replaceAll(',', ''));

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ShopRepository.instance.saveVoucher(
        id: widget.voucher?['id'] as String?,
        code: _code.text,
        title: _title.text,
        discountType: _type,
        discountValue: _int(_value.text)!,
        minimumPurchase: _int(_minimum.text) ?? 0,
        maximumDiscount: _maximum.text.trim().isEmpty ? null : _int(_maximum.text),
        usageLimit: _usageLimit.text.trim().isEmpty ? null : _int(_usageLimit.text),
        usagePerUser: _int(_perUser.text) ?? 1,
        active: _active,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.primaryDark));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.voucher == null ? 'Tambah Voucher' : 'Edit Voucher')),
      body: Form(
        key: _key,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Kode voucher'),
              validator: (value) => value == null || value.trim().length < 3 ? 'Kode minimal 3 karakter.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Judul promo'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Wajib diisi.' : null,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Jenis diskon'),
              items: const [
                DropdownMenuItem(value: 'fixed', child: Text('Nominal tetap (Rp)')),
                DropdownMenuItem(value: 'percentage', child: Text('Persentase (%)')),
              ],
              onChanged: (value) => setState(() => _type = value ?? 'fixed'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _type == 'percentage' ? 'Nilai diskon (%)' : 'Nilai diskon (Rp)'),
              validator: (value) {
                final number = _int(value ?? '') ?? 0;
                if (number <= 0) return 'Nilai diskon harus lebih dari 0.';
                if (_type == 'percentage' && number > 100) return 'Persentase maksimal 100.';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _minimum,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minimum pembelian', prefixText: 'Rp '),
              validator: (value) => (_int(value ?? '') ?? -1) < 0 ? 'Tidak valid.' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _maximum,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maksimum diskon (opsional)', prefixText: 'Rp '),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _usageLimit,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Kuota total (opsional)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _perUser,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Maks/user'),
                    validator: (value) => (_int(value ?? '') ?? 0) <= 0 ? 'Minimal 1.' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Voucher aktif'),
              subtitle: const Text('Voucher aktif dapat dipakai pada checkout selama periode masih berlaku.'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan Voucher')),
          ],
        ),
      ),
    );
  }
}
