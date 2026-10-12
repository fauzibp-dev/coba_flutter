import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/commerce_repository.dart';
import '../services/shop_repository.dart';
import 'address_book_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _voucher = TextEditingController();
  final _notes = TextEditingController();
  final _scroll = ScrollController(keepScrollOffset: false);
  final _requestId = const Uuid().v4();
  String _payment = 'cod';
  String _shipping = 'local_delivery';
  String? _addressId;
  bool _submitting = false;
  bool _quoting = false;
  late Future<List<dynamic>> _future;
  Map<String, dynamic>? _quote;
  Map<String, dynamic>? _settings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _voucher.dispose();
    _notes.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _reload() {
    _future = Future.wait<dynamic>([
      ShopRepository.instance.cartItems(),
      ShopRepository.instance.addresses(),
      // Bank settings are optional for COD. Do not blank checkout if they fail.
      CommerceRepository.instance.storeSettings()
          .timeout(const Duration(seconds: 8))
          .catchError((Object error) => <String, dynamic>{}),
    ]).timeout(const Duration(seconds: 20));
  }

  Future<void> _openAddresses() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressBookScreen()));
    if (mounted) {
      setState(() {
        _quote = null;
        _reload();
      });
    }
  }

  Future<void> _loadQuote() async {
    if (_shipping == 'local_delivery' && _addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih alamat pengiriman terlebih dahulu.')));
      return;
    }
    setState(() => _quoting = true);
    try {
      final quote = await CommerceRepository.instance.checkoutQuote(
        addressId: _shipping == 'local_delivery' ? _addressId : null,
        shippingMethod: _shipping,
        voucherCode: _voucher.text,
      );
      if (mounted) setState(() => _quote = quote);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _submit() async {
    if (_shipping == 'local_delivery' && _addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih alamat pengiriman terlebih dahulu.')));
      return;
    }
    if (_quote == null) {
      await _loadQuote();
      if (_quote == null) return;
    }
    setState(() => _submitting = true);
    try {
      final orderId = await ShopRepository.instance.checkout(
        addressId: _shipping == 'local_delivery' ? _addressId : null,
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
            _payment == 'manual_transfer'
                ? 'ID transaksi: ${orderId.substring(0, 8).toUpperCase()}\n\nUnggah bukti pembayaran dari Detail Pesanan sebelum batas waktu pembayaran.'
                : 'ID transaksi: ${orderId.substring(0, 8).toUpperCase()}\n\nPesanan COD sudah dikonfirmasi dan masuk proses fulfillment.',
          ),
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

  void _invalidateQuote() {
    setState(() => _quote = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout'), actions: [
        IconButton(tooltip: 'Muat ulang checkout', icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() { _quote = null; _reload(); })),
      ]),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Memuat keranjang dan alamat checkout...'),
            ]));
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.report_problem_outlined, color: AppTheme.error, size: 38),
                const SizedBox(height: 12),
                Text('Checkout gagal dimuat: ${snapshot.hasError ? friendlyError(snapshot.error!) : 'Tidak ada data'}',
                  textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => setState(() { _quote = null; _reload(); }),
                  icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
              ]),
            ));
          }
          final items = snapshot.data![0] as List<Map<String, dynamic>>;
          final addresses = snapshot.data![1] as List<Map<String, dynamic>>;
          _settings = snapshot.data![2] as Map<String, dynamic>;
          if (items.isEmpty) return const Center(child: Text('Keranjang kosong.'));
          if (addresses.isNotEmpty &&
              !addresses.any((a) => a['id']?.toString() == _addressId)) {
            final selected = addresses.firstWhere(
              (a) => a['is_default'] == true, orElse: () => addresses.first);
            _addressId = selected['id']?.toString();
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scroll,
                  key: const PageStorageKey('kkmp-checkout-items'),
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Section(
                      title: 'Alamat & Fulfillment',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'local_delivery', icon: Icon(Icons.local_shipping_outlined), label: Text('Diantar')),
                              ButtonSegment(value: 'pickup', icon: Icon(Icons.storefront_outlined), label: Text('Ambil')),
                            ],
                            selected: {_shipping},
                            onSelectionChanged: (v) {
                              _shipping = v.first;
                              _invalidateQuote();
                            },
                          ),
                          const SizedBox(height: 12),
                          if (_shipping == 'pickup')
                            const Text('Pesanan diambil langsung di koperasi. Alamat tidak diperlukan.', style: TextStyle(color: AppTheme.textSecondary))
                          else if (addresses.isEmpty)
                            const Text('Belum ada alamat. Tambahkan alamat terlebih dahulu.', style: TextStyle(color: AppTheme.textSecondary))
                          else
                            DropdownButtonFormField<String>(
                              initialValue: _addressId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Alamat pengiriman'),
                              items: addresses
                                  .map((a) => DropdownMenuItem(
                                        value: a['id'] as String,
                                        child: Text('${a['label']} • ${a['recipient_name']} — ${a['address_line']}', overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                _addressId = v;
                                _invalidateQuote();
                              },
                            ),
                          if (_shipping == 'local_delivery') ...[
                            const SizedBox(height: 10),
                            OutlinedButton.icon(onPressed: _openAddresses, icon: const Icon(Icons.location_on_outlined), label: const Text('Kelola alamat')),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Produk (${items.length})',
                      child: Column(
                        children: items.map((item) {
                          final product = Map<String, dynamic>.from(item['products'] as Map);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: Row(
                              children: [
                                Expanded(child: Text('${product['name']} ×${item['quantity']}', maxLines: 2, overflow: TextOverflow.ellipsis)),
                                Text('Stok tervalidasi server', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                              ],
                            ),
                          );
                        }).toList(),
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
                            subtitle: Text(
                              (_settings?['bank_name']?.toString().isNotEmpty ?? false)
                                  ? '${_settings!['bank_name']} • ${_settings!['bank_account_number'] ?? '-'} a.n. ${_settings!['bank_account_name'] ?? '-'}'
                                  : 'Bukti transfer diunggah dari detail pesanan dan diverifikasi admin.',
                            ),
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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _voucher,
                                  textCapitalization: TextCapitalization.characters,
                                  onChanged: (_) => _invalidateQuote(),
                                  decoration: const InputDecoration(labelText: 'Kode voucher'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(onPressed: _quoting ? null : _loadQuote, child: Text(_quoting ? '...' : 'Terapkan')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan pesanan (opsional)')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Section(
                      title: 'Ringkasan Server',
                      child: _quote == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text('Minta kalkulasi final dari server agar harga, promo, stok, dan ongkir yang tampil sama dengan order yang dibuat.', style: TextStyle(color: AppTheme.textSecondary, height: 1.4)),
                                const SizedBox(height: 10),
                                OutlinedButton(onPressed: _quoting ? null : _loadQuote, child: Text(_quoting ? 'Menghitung...' : 'Hitung Total Final')),
                              ],
                            )
                          : Column(
                              children: [
                                _TotalRow(label: 'Subtotal', value: rupiah((_quote!['subtotal'] ?? 0) as num)),
                                _TotalRow(label: 'Diskon', value: '- ${rupiah((_quote!['discount'] ?? 0) as num)}'),
                                _TotalRow(label: 'Pengiriman', value: rupiah((_quote!['shipping'] ?? 0) as num)),
                                const Divider(height: 22),
                                _TotalRow(label: 'Total', value: rupiah((_quote!['total'] ?? 0) as num), bold: true),
                                if (_quote!['voucher_title'] != null) ...[
                                  const SizedBox(height: 6),
                                  Align(alignment: Alignment.centerLeft, child: Text('Voucher: ${_quote!['voucher_title']}', style: const TextStyle(fontSize: 11, color: AppTheme.success))),
                                ],
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
                  child: SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(_submitting ? 'Membuat pesanan...' : 'Buat Pesanan'),
                  )),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 12), child]),
      );
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value, this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? AppTheme.primary : null)),
          ],
        ),
      );
}
