import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/shop_repository.dart';
import 'address_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late Future<List<dynamic>> _future;
  final _voucher = TextEditingController();
  final _notes = TextEditingController();
  final _requestId = newRequestId();
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
    if (variant is Map && variant['price_override'] != null) {
      return variant['price_override'] as num;
    }
    return (product['price'] ?? 0) as num;
  }

  Future<void> _manageAddress() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressScreen()));
    if (mounted) setState(_reload);
  }

  Future<void> _submit() async {
    if (_shipping == 'local_delivery' && _addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih atau tambahkan alamat terlebih dahulu.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final orderId = await ShopRepository.instance.checkout(
        addressId: _shipping == 'pickup' ? null : _addressId,
        paymentMethod: _payment,
        shippingMethod: _shipping,
        clientRequestId: _requestId,
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
          content: Text(
            'ID transaksi: ${orderId.substring(0, 8).toUpperCase()}\n\n'
            'Status dan detail pesanan dapat dilihat di menu Pesanan.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Selesai')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e)), backgroundColor: AppTheme.primaryDark),
        );
      }
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Checkout tidak dapat dimuat: ${friendlyError(snapshot.error!)}'));
          }
          final items = snapshot.data![0] as List<Map<String, dynamic>>;
          final addresses = snapshot.data![1] as List<Map<String, dynamic>>;
          if (_addressId == null && addresses.isNotEmpty) {
            final defaultAddress = addresses.firstWhere(
              (a) => a['is_default'] == true,
              orElse: () => addresses.first,
            );
            _addressId = defaultAddress['id'] as String;
          }
          final subtotal = items.fold<num>(
            0,
            (sum, item) => sum + _price(item) * ((item['quantity'] ?? 1) as num),
          );
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
                          if (_shipping == 'pickup')
                            const Text(
                              'Tidak perlu alamat untuk pengambilan langsung di koperasi.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            )
                          else if (addresses.isEmpty)
                            const Text('Belum ada alamat pengiriman.', style: TextStyle(color: AppTheme.textSecondary))
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _addressId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Alamat pengiriman'),
                              items: addresses.map((a) {
                                return DropdownMenuItem(
                                  value: a['id'] as String,
                                  child: Text(
                                    '${a['label']} • ${a['recipient_name']} — ${a['address_line']}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) => setState(() => _addressId = value),
                            ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _manageAddress,
                            icon: const Icon(Icons.location_on_outlined),
                            label: Text(addresses.isEmpty ? 'Tambah alamat' : 'Kelola alamat'),
                          ),
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
                                Expanded(
                                  child: Text(
                                    '${product['name']} ×${item['quantity']}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  rupiah(_price(item) * ((item['quantity'] ?? 1) as num)),
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
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
                            onChanged: (value) => setState(() => _shipping = value!),
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'pickup',
                            groupValue: _shipping,
                            title: const Text('Ambil di Koperasi'),
                            subtitle: const Text('Tanpa ongkir'),
                            onChanged: (value) => setState(() => _shipping = value!),
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
                            onChanged: (value) => setState(() => _payment = value!),
                          ),
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: 'manual_transfer',
                            groupValue: _payment,
                            title: const Text('Transfer manual'),
                            subtitle: const Text('Konfirmasi pembayaran diproses admin koperasi.'),
                            onChanged: (value) => setState(() => _payment = value!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Voucher & Catatan',
                      child: Column(
                        children: [
                          TextField(
                            controller: _voucher,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(labelText: 'Kode voucher (opsional)'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _notes,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Catatan pesanan (opsional)'),
                          ),
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
                          const Text(
                            'Voucher, harga, dan stok divalidasi ulang oleh server. Checkout juga memakai request ID agar retry tidak membuat order ganda.',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
                          ),
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
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Membuat pesanan...' : 'Buat Pesanan'),
                  ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
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
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
            color: bold ? AppTheme.primary : null,
            fontSize: bold ? 18 : 14,
          ),
        ),
      ],
    );
  }
}
