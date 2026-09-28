import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late Future<List<dynamic>> _future;
  final _voucher = TextEditingController();
  final _notes = TextEditingController();
  String _payment = 'cod';
  String _shipping = 'local_delivery';
  String? _addressId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _voucher.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _reload() {
    _future = Future.wait([
      ShopRepository.instance.cartItems(),
      ShopRepository.instance.addresses(),
    ]);
  }

  num _price(Map<String, dynamic> item) {
    final product = Map<String, dynamic>.from(item['products'] as Map);
    final variant = item['product_variants'];
    if (variant is Map && variant['price_override'] != null) return variant['price_override'] as num;
    return (product['price'] ?? 0) as num;
  }

  Future<void> _addAddress() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _AddressFormSheet(),
    );
    if (created == true && mounted) setState(_reload);
  }

  Future<void> _submit() async {
    if (_addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih atau tambahkan alamat terlebih dahulu.')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final orderId = await ShopRepository.instance.checkout(
        addressId: _addressId!,
        paymentMethod: _payment,
        shippingMethod: _shipping,
        voucherCode: _voucher.text,
        notes: _notes.text,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 48),
          title: const Text('Pesanan berhasil dibuat'),
          content: Text('ID transaksi: ${orderId.substring(0, 8).toUpperCase()}\n\nStatus dan detail pesanan dapat dilihat di menu Pesanan.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Selesai'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.primaryDark));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return const Center(child: Text('Checkout tidak dapat dimuat.'));
          final items = snapshot.data![0] as List<Map<String, dynamic>>;
          final addresses = snapshot.data![1] as List<Map<String, dynamic>>;
          if (_addressId == null && addresses.isNotEmpty) {
            final defaultAddress = addresses.cast<Map<String, dynamic>>().firstWhere(
                  (a) => a['is_default'] == true,
                  orElse: () => addresses.first,
                );
            _addressId = defaultAddress['id'] as String;
          }
          final subtotal = items.fold<num>(0, (sum, e) => sum + _price(e) * ((e['quantity'] ?? 1) as num));
          final shippingCost = _shipping == 'local_delivery' ? 5000 : 0;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Section(
                      title: 'Alamat',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (addresses.isEmpty)
                            const Text('Belum ada alamat pengiriman.', style: TextStyle(color: AppTheme.textSecondary))
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _addressId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Alamat pengiriman'),
                              items: addresses.map((a) {
                                return DropdownMenuItem(
                                  value: a['id'] as String,
                                  child: Text('${a['label']} • ${a['recipient_name']} — ${a['address_line']}', overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _addressId = v),
                            ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(onPressed: _addAddress, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Tambah alamat')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Pesanan',
                      child: Column(
                        children: items.map((item) {
                          final product = Map<String, dynamic>.from(item['products'] as Map);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(child: Text('${product['name']}  ×${item['quantity']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 10),
                                Text(rupiah(_price(item) * ((item['quantity'] ?? 1) as num)), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Pengiriman',
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'local_delivery',
                            groupValue: _shipping,
                            title: const Text('Local Delivery'),
                            subtitle: const Text('Tarif awal Rp5.000'),
                            onChanged: (v) => setState(() => _shipping = v!),
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'pickup',
                            groupValue: _shipping,
                            title: const Text('Ambil di Koperasi'),
                            subtitle: const Text('Tanpa ongkir'),
                            onChanged: (v) => setState(() => _shipping = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Pembayaran',
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'cod',
                            groupValue: _payment,
                            title: const Text('COD / Bayar saat diterima'),
                            onChanged: (v) => setState(() => _payment = v!),
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'manual_transfer',
                            groupValue: _payment,
                            title: const Text('Transfer manual'),
                            subtitle: const Text('Konfirmasi pembayaran diproses admin koperasi.'),
                            onChanged: (v) => setState(() => _payment = v!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Voucher & Catatan',
                      child: Column(
                        children: [
                          TextField(controller: _voucher, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Kode voucher (opsional)')),
                          const SizedBox(height: 10),
                          TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan pesanan (opsional)')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Ringkasan',
                      child: Column(
                        children: [
                          _TotalRow(label: 'Subtotal', value: rupiah(subtotal)),
                          const SizedBox(height: 7),
                          _TotalRow(label: 'Pengiriman', value: rupiah(shippingCost)),
                          const Divider(height: 22),
                          _TotalRow(label: 'Estimasi total', value: rupiah(subtotal + shippingCost), bold: true),
                          const SizedBox(height: 6),
                          const Text('Voucher dan seluruh harga divalidasi ulang oleh server sebelum order dibuat.', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: FilledButton(onPressed: _submitting ? null : _submit, child: Text(_submitting ? 'Membuat pesanan...' : 'Buat Pesanan')),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
        Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? AppTheme.primary : null, fontSize: bold ? 18 : 14)),
      ],
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  const _AddressFormSheet();
  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _province = TextEditingController(text: 'Jawa Tengah');
  final _city = TextEditingController(text: 'Surakarta');
  final _district = TextEditingController(text: 'Laweyan');
  final _address = TextEditingController();
  final _postal = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _province, _city, _district, _address, _postal]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ShopRepository.instance.addAddress(
        label: 'Rumah',
        recipientName: _name.text,
        phone: _phone.text,
        province: _province.text,
        city: _city.text,
        district: _district.text,
        addressLine: _address.text,
        postalCode: _postal.text,
        isDefault: true,
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
              const Text('Tambah Alamat', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
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
              TextFormField(controller: _address, minLines: 2, maxLines: 3, decoration: const InputDecoration(labelText: 'Alamat lengkap'), validator: _required),
              const SizedBox(height: 10),
              TextFormField(controller: _postal, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kode pos (opsional)')),
              const SizedBox(height: 16),
              FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Simpan Alamat')),
            ],
          ),
        ),
      ),
    );
  }

  static String? _required(String? value) => value == null || value.trim().isEmpty ? 'Wajib diisi.' : null;
}
