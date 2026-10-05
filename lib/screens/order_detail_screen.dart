import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/app_utils.dart';
import '../services/commerce_repository.dart';
import '../services/shop_repository.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});
  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Future.wait([
      ShopRepository.instance.orderDetail(widget.orderId),
      CommerceRepository.instance.storeSettings(),
    ]);
  }

  String _status(String value) {
    const labels = {
      'pending_payment': 'Menunggu Pembayaran', 'paid': 'Sudah Dibayar', 'confirmed': 'Dikonfirmasi',
      'processing': 'Sedang Diproses', 'ready_to_ship': 'Siap Dikirim', 'shipped': 'Dikirim',
      'delivered': 'Sudah Tiba', 'completed': 'Selesai', 'cancelled': 'Dibatalkan',
      'return_requested': 'Pengembalian Diajukan', 'returned': 'Dikembalikan',
      'refund_pending': 'Refund Diproses', 'refunded': 'Refund Selesai', 'pending': 'Menunggu',
      'approved': 'Disetujui', 'rejected': 'Ditolak', 'expired': 'Kedaluwarsa',
    };
    return labels[value] ?? value.replaceAll('_', ' ');
  }

  String _date(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    return d == null ? '-' : DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(d.toLocal());
  }

  Future<void> _review(Map<String, dynamic> item) async {
    final orderItemId = item['id'] as String;
    final productId = item['product_id'] as String?;
    if (productId == null) return;
    final existing = await ShopRepository.instance.reviewForOrderItem(orderItemId);
    if (!mounted) return;
    if (existing != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Produk ini sudah kamu ulas.')));
      return;
    }
    final saved = await showDialog<bool>(context: context, builder: (_) => _ReviewDialog(item: item));
    if (saved == true && mounted) setState(_reload);
  }

  Future<void> _uploadPaymentProof(Map<String, dynamic> order) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 88);
    if (picked == null || !mounted) return;
    final payer = TextEditingController();
    final bank = TextEditingController();
    final amount = TextEditingController(text: ((order['total_amount'] ?? 0) as num).toInt().toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kirim Bukti Transfer'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: payer, decoration: const InputDecoration(labelText: 'Nama pengirim')),
          const SizedBox(height: 8),
          TextField(controller: bank, decoration: const InputDecoration(labelText: 'Bank pengirim')),
          const SizedBox(height: 8),
          TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nominal')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Kirim')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await CommerceRepository.instance.uploadPaymentProof(orderId: widget.orderId, file: picked, bankName: bank.text, payerName: payer.text, amount: num.tryParse(amount.text));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bukti transfer berhasil dikirim.')));
          setState(_reload);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    payer.dispose(); bank.dispose(); amount.dispose();
  }

  Future<void> _requestReturn(Map<String, dynamic> order) async {
    final items = (order['order_items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final selected = <String, bool>{for (final item in items) item['id'].toString(): false};
    final quantities = <String, TextEditingController>{for (final item in items) item['id'].toString(): TextEditingController(text: '1')};
    final reason = TextEditingController();
    final detail = TextEditingController();
    var resolution = 'refund';
    XFile? evidence;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ajukan Pengembalian'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ...items.map((item) {
                  final id = item['id'].toString();
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected[id],
                    onChanged: (v) => setDialogState(() => selected[id] = v == true),
                    title: Text(item['product_name']?.toString() ?? '-'),
                    subtitle: Text('Dibeli: ${item['quantity']}'),
                    secondary: SizedBox(width: 68, child: TextField(controller: quantities[id], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qty'))),
                  );
                }),
                const SizedBox(height: 8),
                TextField(controller: reason, decoration: const InputDecoration(labelText: 'Alasan *')),
                const SizedBox(height: 8),
                TextField(controller: detail, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Detail')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: resolution,
                  decoration: const InputDecoration(labelText: 'Penyelesaian yang diminta'),
                  items: const [
                    DropdownMenuItem(value: 'refund', child: Text('Refund')),
                    DropdownMenuItem(value: 'replace', child: Text('Penggantian barang')),
                    DropdownMenuItem(value: 'store_credit', child: Text('Saldo toko')),
                  ],
                  onChanged: (v) => setDialogState(() => resolution = v ?? 'refund'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
                    if (file != null) setDialogState(() => evidence = file);
                  },
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(evidence == null ? 'Tambah foto bukti' : 'Foto bukti dipilih'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(
              onPressed: () {
                final any = selected.values.any((v) => v);
                if (!any || reason.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Ajukan'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final requestItems = <Map<String, dynamic>>[];
      for (final item in items) {
        final id = item['id'].toString();
        if (selected[id] != true) continue;
        final qty = int.tryParse(quantities[id]!.text) ?? 0;
        final max = ((item['quantity'] ?? 0) as num).toInt();
        if (qty < 1 || qty > max) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Qty retur ${item['product_name']} tidak valid.')));
          for (final c in quantities.values) { c.dispose(); }
          reason.dispose(); detail.dispose();
          return;
        }
        requestItems.add({'order_item_id': id, 'quantity': qty, 'reason': reason.text.trim()});
      }
      try {
        final returnId = await CommerceRepository.instance.requestReturn(orderId: widget.orderId, reason: reason.text, description: detail.text, resolution: resolution, items: requestItems);
        if (evidence != null) await CommerceRepository.instance.uploadReturnEvidence(returnId: returnId, file: evidence!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengajuan pengembalian terkirim.')));
          setState(_reload);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    for (final c in quantities.values) { c.dispose(); }
    reason.dispose(); detail.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail Pesanan')),
        body: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError || !snapshot.hasData) return Center(child: Text('Detail pesanan tidak dapat dimuat: ${snapshot.hasError ? friendlyError(snapshot.error!) : ''}'));
            final order = snapshot.data![0] as Map<String, dynamic>;
            final settings = snapshot.data![1] as Map<String, dynamic>;
            final items = (order['order_items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final history = (order['order_status_history'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList()..sort((a, b) => (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));
            final shipments = (order['shipments'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final proofs = (order['manual_payment_proofs'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final returns = (order['returns'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            final address = order['address_snapshot'];
            final status = order['status']?.toString() ?? '';
            final isManualPending = order['payment_method'] == 'manual_transfer' && order['payment_status'] == 'pending' && status == 'pending_payment';
            return RefreshIndicator(
              onRefresh: () async { setState(_reload); await _future; },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text(order['order_number']?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), _Badge(label: _status(status))]),
                    const SizedBox(height: 6),
                    Text(_date(order['created_at']), style: const TextStyle(color: AppTheme.textSecondary)),
                    const Divider(height: 24),
                    _row('Pembayaran', order['payment_method'] == 'cod' ? 'COD' : 'Transfer manual'),
                    _row('Status bayar', _status(order['payment_status']?.toString() ?? '-')),
                    _row('Pengiriman', order['shipping_method'] == 'pickup' ? 'Ambil di koperasi' : 'Local Delivery'),
                  ])),
                  if (isManualPending) ...[
                    const SizedBox(height: 12),
                    _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Selesaikan Transfer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(height: 7),
                      if (settings['bank_name'] != null) Text('${settings['bank_name']} • ${settings['bank_account_number'] ?? '-'}\na.n. ${settings['bank_account_name'] ?? '-'}'),
                      const SizedBox(height: 5),
                      Text('Bayar sebelum: ${_date(order['payment_due_at'])}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      FilledButton.icon(onPressed: () => _uploadPaymentProof(order), icon: const Icon(Icons.upload_file_rounded), label: const Text('Unggah Bukti Transfer')),
                      if (proofs.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ...proofs.map((p) => Text('Bukti ${_date(p['created_at'])} • ${_status(p['status']?.toString() ?? 'pending')}${p['admin_note'] == null ? '' : ' • ${p['admin_note']}'}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))),
                      ],
                    ])),
                  ],
                  const SizedBox(height: 12),
                  _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Produk', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    ...items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(children: [
                        Row(children: [Expanded(child: Text('${item['product_name']} ×${item['quantity']}')), Text(rupiah((item['subtotal'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700))]),
                        if (status == 'completed' && item['product_id'] != null) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _review(item), icon: const Icon(Icons.star_border_rounded), label: const Text('Beri Ulasan'))),
                      ]),
                    )),
                    const Divider(),
                    _row('Subtotal', rupiah((order['subtotal'] ?? 0) as num)),
                    _row('Diskon', '- ${rupiah((order['discount_amount'] ?? 0) as num)}'),
                    _row('Pengiriman', rupiah((order['shipping_cost'] ?? 0) as num)),
                    const Divider(),
                    _row('Total', rupiah((order['total_amount'] ?? 0) as num), bold: true),
                  ])),
                  if (address is Map) ...[
                    const SizedBox(height: 12),
                    _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Alamat Pengiriman', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('${address['recipient_name']} • ${address['phone']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${address['address_line']}, ${address['district']}, ${address['city']}, ${address['province']}'),
                    ])),
                  ],
                  if (shipments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...shipments.map((shipment) {
                      final events = (shipment['shipment_events'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList()..sort((a,b) => (b['created_at']?.toString() ?? '').compareTo(a['created_at']?.toString() ?? ''));
                      return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Pengiriman', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        const SizedBox(height: 7),
                        _row('Status', _status(shipment['status']?.toString() ?? '-')),
                        _row('Kode', shipment['internal_delivery_code']?.toString() ?? '-'),
                        if (shipment['tracking_number'] != null) _row('Resi', shipment['tracking_number'].toString()),
                        if (shipment['driver_name'] != null) _row('Kurir', '${shipment['driver_name']} • ${shipment['driver_phone'] ?? '-'}'),
                        if (events.isNotEmpty) ...[
                          const Divider(height: 22),
                          ...events.take(6).map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${_status(e['status']?.toString() ?? '-')} • ${e['description'] ?? ''}\n${_date(e['created_at'])}${e['location'] == null ? '' : ' • ${e['location']}'}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)))),
                        ],
                      ]));
                    }),
                  ],
                  const SizedBox(height: 12),
                  _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Timeline Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 12),
                    if (history.isEmpty) const Text('Belum ada histori status.', style: TextStyle(color: AppTheme.textSecondary)) else ...history.map((h) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.success)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_status(h['status']?.toString() ?? ''), style: const TextStyle(fontWeight: FontWeight.w800)), if (h['note'] != null) Text(h['note'].toString(), style: const TextStyle(fontSize: 12)), Text(_date(h['created_at']), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))])),
                    ]))),
                  ])),
                  if ((status == 'delivered' || status == 'completed') && returns.isEmpty) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(onPressed: () => _requestReturn(order), icon: const Icon(Icons.assignment_return_outlined), label: const Text('Ajukan Pengembalian / Refund')),
                  ],
                  if (returns.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Pengembalian', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ...returns.map((r) => Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_status(r['status']?.toString() ?? 'requested')} • ${r['reason'] ?? '-'}${r['admin_note'] == null ? '' : '\nAdmin: ${r['admin_note']}'}'))),
                    ])),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Expanded(child: Text(label, style: TextStyle(color: bold ? null : AppTheme.textSecondary, fontWeight: bold ? FontWeight.w800 : FontWeight.w400))), Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? AppTheme.primary : null))]),
      );
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog({required this.item});
  final Map<String, dynamic> item;
  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _comment = TextEditingController();
  int _rating = 5;
  bool _saving = false;
  XFile? _image;

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file != null && mounted) setState(() => _image = file);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final id = await ShopRepository.instance.submitReview(orderItemId: widget.item['id'] as String, productId: widget.item['product_id'] as String, rating: _rating, comment: _comment.text);
      if (_image != null) await CommerceRepository.instance.uploadReviewImage(reviewId: id, file: _image!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Ulas ${widget.item['product_name']}'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(children: List.generate(5, (i) => IconButton(onPressed: () => setState(() => _rating = i + 1), icon: Icon(i < _rating ? Icons.star_rounded : Icons.star_border_rounded, color: const Color(0xFFF5A623))))),
          TextField(controller: _comment, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Komentar (opsional)')),
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(_image == null ? 'Tambah Foto' : 'Ganti Foto')),
          if (_image != null) ...[
            const SizedBox(height: 8),
            FutureBuilder<Uint8List>(future: _image!.readAsBytes(), builder: (_, snap) => snap.hasData ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(snap.data!, height: 100, fit: BoxFit.cover)) : const SizedBox(height: 30, child: Center(child: CircularProgressIndicator()))),
          ],
        ])),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Menyimpan...' : 'Kirim Ulasan')),
        ],
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.border)), child: child);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)), child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.success)));
}
