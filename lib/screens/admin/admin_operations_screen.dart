import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/admin_operations_repository.dart';

class AdminOperationsScreen extends StatefulWidget {
  const AdminOperationsScreen({super.key});

  @override
  State<AdminOperationsScreen> createState() => _AdminOperationsScreenState();
}

class _AdminOperationsScreenState extends State<AdminOperationsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    final repo = AdminOperationsRepository.instance;
    _future = Future.wait([
      repo.shipments(),
      repo.paymentProofs(),
      repo.stocktakes(),
      repo.suppliers(),
      repo.purchaseOrders(),
      repo.settings(),
      repo.deliveryZones(),
    ]);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Operasional Toko', style: TextStyle(fontWeight: FontWeight.w900)),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Fulfillment'),
            Tab(text: 'Pembayaran'),
            Tab(text: 'Gudang'),
            Tab(text: 'Pengaturan'),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Operasional gagal dimuat: ${friendlyError(snapshot.error!)}'));
          final data = snapshot.data!;
          return TabBarView(
            controller: _tabs,
            children: [
              _FulfillmentTab(rows: data[0] as List<Map<String, dynamic>>, onChanged: _refresh),
              _PaymentsTab(rows: data[1] as List<Map<String, dynamic>>, onChanged: _refresh),
              _WarehouseTab(
                stocktakes: data[2] as List<Map<String, dynamic>>,
                suppliers: data[3] as List<Map<String, dynamic>>,
                purchaseOrders: data[4] as List<Map<String, dynamic>>,
                onChanged: _refresh,
              ),
              _SettingsTab(settings: data[5] as Map<String, dynamic>, zones: data[6] as List<Map<String, dynamic>>, onChanged: _refresh),
            ],
          );
        },
      ),
    );
  }
}

class _FulfillmentTab extends StatelessWidget {
  const _FulfillmentTab({required this.rows, required this.onChanged});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function() onChanged;

  Future<void> _edit(BuildContext context, Map<String, dynamic> row) async {
    final status = ValueNotifier<String>(row['status']?.toString() ?? 'pending');
    final driver = TextEditingController(text: row['driver_name']?.toString() ?? '');
    final phone = TextEditingController(text: row['driver_phone']?.toString() ?? '');
    final tracking = TextEditingController(text: row['tracking_number']?.toString() ?? '');
    final note = TextEditingController();
    final location = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Fulfillment ${row['internal_delivery_code'] ?? ''}'),
        content: SingleChildScrollView(
          child: ValueListenableBuilder<String>(
            valueListenable: status,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: value,
                  decoration: const InputDecoration(labelText: 'Status pengiriman'),
                  items: const [
                    'pending',
                    'assigned',
                    'ready_for_pickup',
                    'picked_up',
                    'in_transit',
                    'failed_attempt',
                    'delivered',
                    'cancelled',
                  ].map((e) => DropdownMenuItem(value: e, child: Text(e.replaceAll('_', ' ')))).toList(),
                  onChanged: (v) => status.value = v ?? value,
                ),
                const SizedBox(height: 10),
                TextField(controller: driver, decoration: const InputDecoration(labelText: 'Nama kurir/driver')),
                const SizedBox(height: 10),
                TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor driver')),
                const SizedBox(height: 10),
                TextField(controller: tracking, decoration: const InputDecoration(labelText: 'Nomor resi/tracking')),
                const SizedBox(height: 10),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'Lokasi event')),
                const SizedBox(height: 10),
                TextField(controller: note, maxLines: 2, decoration: const InputDecoration(labelText: 'Catatan status')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AdminOperationsRepository.instance.updateShipment(
          id: row['id'] as String,
          status: status.value,
          description: note.text,
          location: location.text,
          driverName: driver.text,
          driverPhone: phone.text,
          trackingNumber: tracking.text,
        );
        await onChanged();
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    status.dispose();
    driver.dispose();
    phone.dispose();
    tracking.dispose();
    note.dispose();
    location.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('Belum ada fulfillment.'));
    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final row = rows[i];
          final order = row['orders'] is Map ? Map<String, dynamic>.from(row['orders'] as Map) : <String, dynamic>{};
          return _Card(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => _edit(context, row),
              leading: const CircleAvatar(child: Icon(Icons.local_shipping_outlined)),
              title: Text(order['order_number']?.toString() ?? row['internal_delivery_code']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${row['shipping_method']} • ${row['status']}\n${row['driver_name'] ?? 'Belum ada driver'}${row['tracking_number'] == null ? '' : ' • ${row['tracking_number']}'}'),
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          );
        },
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.rows, required this.onChanged});
  final List<Map<String, dynamic>> rows;
  final Future<void> Function() onChanged;

  Future<void> _review(BuildContext context, Map<String, dynamic> row, bool approve) async {
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Setujui Pembayaran' : 'Tolak Bukti Pembayaran'),
        content: TextField(controller: note, maxLines: 3, decoration: InputDecoration(labelText: approve ? 'Catatan (opsional)' : 'Alasan penolakan')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(approve ? 'Setujui' : 'Tolak')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await AdminOperationsRepository.instance.verifyPaymentProof(row['id'] as String, approve, note: note.text);
        await onChanged();
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const Center(child: Text('Belum ada bukti pembayaran.'));
    return RefreshIndicator(
      onRefresh: onChanged,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final row = rows[i];
          final order = row['orders'] is Map ? Map<String, dynamic>.from(row['orders'] as Map) : <String, dynamic>{};
          final pending = row['status'] == 'pending';
          return _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(order['order_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))),
                    _Badge(label: row['status']?.toString() ?? '-'),
                  ],
                ),
                const SizedBox(height: 5),
                Text('${row['bank_name'] ?? '-'} • ${row['payer_name'] ?? '-'} • ${rupiah((row['amount'] ?? order['total_amount'] ?? 0) as num)}', style: const TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                FutureBuilder<String>(
                  future: AdminOperationsRepository.instance.signedPaymentProofUrl(row['proof_path'].toString()),
                  builder: (context, snapshot) => snapshot.hasData
                      ? SelectableText('Bukti: ${snapshot.data}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))
                      : const Text('Menyiapkan link bukti...', style: TextStyle(fontSize: 11)),
                ),
                if (pending) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () => _review(context, row, false), child: const Text('Tolak'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton(onPressed: () => _review(context, row, true), child: const Text('Setujui'))),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WarehouseTab extends StatelessWidget {
  const _WarehouseTab({required this.stocktakes, required this.suppliers, required this.purchaseOrders, required this.onChanged});
  final List<Map<String, dynamic>> stocktakes;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> purchaseOrders;
  final Future<void> Function() onChanged;

  Future<void> _addSupplier(BuildContext context) async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tambah Supplier'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama supplier')),
          const SizedBox(height: 8),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telepon')),
          const SizedBox(height: 8),
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, name.text.trim().isNotEmpty), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) {
      await AdminOperationsRepository.instance.saveSupplier(name: name.text, phone: phone.text, email: email.text);
      await onChanged();
    }
    name.dispose(); phone.dispose(); email.dispose();
  }

  Future<void> _stocktake(BuildContext context) async {
    try {
      await AdminOperationsRepository.instance.createStocktake(notes: 'Stocktake dari KKMP Kerten Admin');
      await onChanged();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _openStocktake(BuildContext context, Map<String, dynamic> stocktake) async {
    final items = (stocktake['stocktake_items'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    await Navigator.push(context, MaterialPageRoute(builder: (_) => _StocktakeDetail(stocktake: stocktake, items: items)));
    await onChanged();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onChanged,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: () => _stocktake(context), icon: const Icon(Icons.fact_check_outlined), label: const Text('Mulai Stocktake'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: () => _addSupplier(context), icon: const Icon(Icons.local_shipping_outlined), label: const Text('Supplier'))),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Stocktake', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            if (stocktakes.isEmpty) const Text('Belum ada stocktake.', style: TextStyle(color: AppTheme.textSecondary)),
            ...stocktakes.take(10).map((row) => _Card(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _openStocktake(context, row),
                    title: Text('Stocktake ${row['created_at']?.toString().substring(0, 10) ?? ''}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${row['status']} • ${(row['stocktake_items'] as List? ?? []).length} item'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                )),
            const SizedBox(height: 16),
            const Text('Supplier', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            if (suppliers.isEmpty) const Text('Belum ada supplier.', style: TextStyle(color: AppTheme.textSecondary)),
            ...suppliers.take(10).map((s) => _Card(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(s['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${s['phone'] ?? '-'} • ${s['email'] ?? '-'}')))),
            const SizedBox(height: 16),
            const Text('Purchase Order', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            if (purchaseOrders.isEmpty) const Text('Belum ada purchase order.', style: TextStyle(color: AppTheme.textSecondary)),
            ...purchaseOrders.take(10).map((po) => _Card(child: ListTile(contentPadding: EdgeInsets.zero, title: Text(po['po_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${po['status']} • ${rupiah((po['total_cost'] ?? 0) as num)}')))),
          ],
        ),
      );
}

class _StocktakeDetail extends StatefulWidget {
  const _StocktakeDetail({required this.stocktake, required this.items});
  final Map<String, dynamic> stocktake;
  final List<Map<String, dynamic>> items;
  @override
  State<_StocktakeDetail> createState() => _StocktakeDetailState();
}

class _StocktakeDetailState extends State<_StocktakeDetail> {
  late final Map<String, TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final item in widget.items)
        item['id'].toString(): TextEditingController(text: item['counted_qty']?.toString() ?? item['system_qty']?.toString() ?? '0'),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      for (final item in widget.items) {
        final id = item['id'].toString();
        final value = int.tryParse(_controllers[id]!.text) ?? -1;
        if (value < 0) throw StateError('Jumlah fisik tidak valid.');
        await AdminOperationsRepository.instance.setStocktakeCount(id, value);
      }
      await AdminOperationsRepository.instance.completeStocktake(widget.stocktake['id'] as String);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Hitung Stok Fisik')),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: widget.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = widget.items[i];
            return _Card(
              child: Row(
                children: [
                  Expanded(child: Text('Produk ${item['product_id'].toString().substring(0, 8)}\nSistem: ${item['system_qty']}', style: const TextStyle(fontWeight: FontWeight.w700))),
                  SizedBox(width: 110, child: TextField(controller: _controllers[item['id'].toString()], keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Fisik'))),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(onPressed: _saving ? null : _complete, child: Text(_saving ? 'Menyimpan...' : 'Selesaikan Stocktake')),
          ),
        ),
      );
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.settings, required this.zones, required this.onChanged});
  final Map<String, dynamic> settings;
  final List<Map<String, dynamic>> zones;
  final Future<void> Function() onChanged;

  Future<void> _editSettings(BuildContext context) async {
    final delivery = TextEditingController(text: '${(settings['local_delivery_fee'] ?? 5000)}');
    final free = TextEditingController(text: settings['free_shipping_threshold']?.toString() ?? '');
    final timeout = TextEditingController(text: '${settings['manual_payment_timeout_minutes'] ?? 120}');
    final bank = TextEditingController(text: settings['bank_name']?.toString() ?? '');
    final bankName = TextEditingController(text: settings['bank_account_name']?.toString() ?? '');
    final bankNumber = TextEditingController(text: settings['bank_account_number']?.toString() ?? '');
    final support = TextEditingController(text: settings['support_phone']?.toString() ?? '');
    final returnDays = TextEditingController(text: '${settings['return_window_days'] ?? 7}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan Commerce'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: delivery, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Ongkir lokal default')),
            const SizedBox(height: 8),
            TextField(controller: free, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Free ongkir minimum (opsional)')),
            const SizedBox(height: 8),
            TextField(controller: timeout, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Batas transfer (menit)')),
            const SizedBox(height: 8),
            TextField(controller: bank, decoration: const InputDecoration(labelText: 'Bank')),
            const SizedBox(height: 8),
            TextField(controller: bankName, decoration: const InputDecoration(labelText: 'Nama rekening')),
            const SizedBox(height: 8),
            TextField(controller: bankNumber, decoration: const InputDecoration(labelText: 'Nomor rekening')),
            const SizedBox(height: 8),
            TextField(controller: support, decoration: const InputDecoration(labelText: 'Nomor support')),
            const SizedBox(height: 8),
            TextField(controller: returnDays, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Jendela retur (hari)')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) {
      await AdminOperationsRepository.instance.saveSettings(
        deliveryFee: num.tryParse(delivery.text) ?? 5000,
        freeShippingThreshold: num.tryParse(free.text),
        paymentTimeoutMinutes: int.tryParse(timeout.text) ?? 120,
        bankName: bank.text,
        bankAccountName: bankName.text,
        bankAccountNumber: bankNumber.text,
        supportPhone: support.text,
        returnWindowDays: int.tryParse(returnDays.text) ?? 7,
      );
      await onChanged();
    }
    delivery.dispose(); free.dispose(); timeout.dispose(); bank.dispose(); bankName.dispose(); bankNumber.dispose(); support.dispose(); returnDays.dispose();
  }

  Future<void> _zone(BuildContext context, [Map<String, dynamic>? zone]) async {
    final name = TextEditingController(text: zone?['name']?.toString() ?? '');
    final city = TextEditingController(text: zone?['city']?.toString() ?? '');
    final district = TextEditingController(text: zone?['district']?.toString() ?? '');
    final fee = TextEditingController(text: zone?['fee']?.toString() ?? '5000');
    final threshold = TextEditingController(text: zone?['free_shipping_threshold']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(zone == null ? 'Tambah Zona' : 'Edit Zona'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama zona')),
          const SizedBox(height: 8),
          TextField(controller: city, decoration: const InputDecoration(labelText: 'Kota (opsional)')),
          const SizedBox(height: 8),
          TextField(controller: district, decoration: const InputDecoration(labelText: 'Kecamatan (opsional)')),
          const SizedBox(height: 8),
          TextField(controller: fee, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tarif')),
          const SizedBox(height: 8),
          TextField(controller: threshold, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Free ongkir minimum')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, name.text.trim().isNotEmpty), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok == true) {
      await AdminOperationsRepository.instance.saveDeliveryZone(
        id: zone?['id']?.toString(),
        name: name.text,
        city: city.text,
        district: district.text,
        fee: num.tryParse(fee.text) ?? 0,
        freeShippingThreshold: num.tryParse(threshold.text),
      );
      await onChanged();
    }
    name.dispose(); city.dispose(); district.dispose(); fee.dispose(); threshold.dispose();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: onChanged,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Commerce Settings', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Ongkir default: ${rupiah((settings['local_delivery_fee'] ?? 0) as num)}'),
                  Text('Batas transfer: ${settings['manual_payment_timeout_minutes']} menit'),
                  Text('Jendela retur: ${settings['return_window_days']} hari'),
                  Text('Rekening: ${settings['bank_name'] ?? '-'} • ${settings['bank_account_number'] ?? '-'}'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(onPressed: () => _editSettings(context), icon: const Icon(Icons.edit_outlined), label: const Text('Edit Pengaturan')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Zona Pengiriman', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                IconButton(onPressed: () => _zone(context), icon: const Icon(Icons.add_circle_outline_rounded)),
              ],
            ),
            if (zones.isEmpty) const Text('Belum ada zona khusus. Tarif default dipakai.', style: TextStyle(color: AppTheme.textSecondary)),
            ...zones.map((z) => _Card(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => _zone(context, z),
                    title: Text(z['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${z['district'] ?? '*'}, ${z['city'] ?? '*'} • ${rupiah((z['fee'] ?? 0) as num)}'),
                    trailing: const Icon(Icons.edit_outlined),
                  ),
                )),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11), border: Border.all(color: AppTheme.border)),
        child: child,
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFFFECEC), borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary)),
      );
}
