import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/admin_operations_repository.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  late Future<List<dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Future.wait([
      AdminOperationsRepository.instance.purchaseOrders(),
      AdminOperationsRepository.instance.suppliers(),
    ]);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _create(List<Map<String, dynamic>> suppliers) async {
    String? supplierId = suppliers.isEmpty ? null : suppliers.first['id']?.toString();
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Purchase Order Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (suppliers.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: supplierId,
                  decoration: const InputDecoration(labelText: 'Supplier'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Tanpa supplier')),
                    ...suppliers.map((s) => DropdownMenuItem<String?>(
                          value: s['id']?.toString(),
                          child: Text(s['name']?.toString() ?? '-'),
                        )),
                  ],
                  onChanged: (v) => setDialogState(() => supplierId = v),
                ),
              if (suppliers.isNotEmpty) const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Buat PO')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        final id = await AdminOperationsRepository.instance.createPurchaseOrder(
          supplierId: supplierId,
          notes: notes.text,
        );
        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: id)),
        );
        if (mounted) await _refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
      }
    }
    notes.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Purchase Order')),
        body: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('PO tidak dapat dimuat: ${friendlyError(snapshot.error!)}'));
            }
            final orders = snapshot.data![0] as List<Map<String, dynamic>>;
            final suppliers = snapshot.data![1] as List<Map<String, dynamic>>;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Restock & Pembelian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                            Text('PO yang diterima otomatis menambah inventory dan movement ledger.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _create(suppliers),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('PO'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (orders.isEmpty)
                    const _Info(text: 'Belum ada purchase order.')
                  else
                    ...orders.map((po) {
                      final supplier = po['suppliers'];
                      final items = po['purchase_order_items'] as List? ?? [];
                      return _Card(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PurchaseOrderDetailScreen(
                                  purchaseOrderId: po['id'] as String,
                                ),
                              ),
                            );
                            if (context.mounted) await _refresh();
                          },
                          leading: const CircleAvatar(child: Icon(Icons.inventory_2_outlined)),
                          title: Text(po['po_number']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: Text(
                            '${supplier is Map ? supplier['name'] ?? 'Tanpa supplier' : 'Tanpa supplier'} • ${items.length} item • ${po['status']}\n${rupiah((po['total_cost'] ?? 0) as num)}',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      );
}

class PurchaseOrderDetailScreen extends StatefulWidget {
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});
  final String purchaseOrderId;

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  late Future<List<dynamic>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = Future.wait([
      AdminOperationsRepository.instance.purchaseOrder(widget.purchaseOrderId),
      AdminOperationsRepository.instance.warehouseProducts(),
    ]);
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _future;
  }

  Future<void> _addItem(
    Map<String, dynamic> po,
    List<Map<String, dynamic>> products,
  ) async {
    if (products.isEmpty) return;
    String productId = products.first['id'].toString();
    String? variantId;
    final qty = TextEditingController(text: '1');
    final cost = TextEditingController(
      text: ((products.first['cost_price'] ?? 0) as num).toInt().toString(),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final product = products.firstWhere((p) => p['id'].toString() == productId);
          final variants = (product['product_variants'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          return AlertDialog(
            title: const Text('Tambah Item PO'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: productId,
                    decoration: const InputDecoration(labelText: 'Produk'),
                    items: products
                        .map((p) => DropdownMenuItem(
                              value: p['id'].toString(),
                              child: Text(p['name']?.toString() ?? '-'),
                            ))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      productId = v ?? productId;
                      variantId = null;
                      final next = products.firstWhere((p) => p['id'].toString() == productId);
                      cost.text = ((next['cost_price'] ?? 0) as num).toInt().toString();
                    }),
                  ),
                  if (variants.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: variantId,
                      decoration: const InputDecoration(labelText: 'Varian'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Produk utama')),
                        ...variants.map((v) => DropdownMenuItem<String?>(
                              value: v['id'].toString(),
                              child: Text(v['name']?.toString() ?? '-'),
                            )),
                      ],
                      onChanged: (v) => setDialogState(() => variantId = v),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: qty,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Jumlah'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: cost,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Harga beli/unit', prefixText: 'Rp '),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              FilledButton(
                onPressed: () {
                  final q = int.tryParse(qty.text) ?? 0;
                  final c = num.tryParse(cost.text) ?? -1;
                  Navigator.pop(context, q > 0 && c >= 0);
                },
                child: const Text('Tambah'),
              ),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      try {
        await AdminOperationsRepository.instance.addPurchaseOrderItem(
          purchaseOrderId: po['id'] as String,
          productId: productId,
          variantId: variantId,
          quantity: int.parse(qty.text),
          unitCost: num.parse(cost.text),
        );
        if (mounted) await _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    qty.dispose();
    cost.dispose();
  }

  Future<void> _markOrdered() async {
    setState(() => _busy = true);
    try {
      await AdminOperationsRepository.instance.markPurchaseOrderOrdered(widget.purchaseOrderId);
      if (mounted) await _refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive(Map<String, dynamic> po) async {
    final items = (po['purchase_order_items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => ((e['received_quantity'] ?? 0) as num).toInt() < ((e['quantity'] ?? 0) as num).toInt())
        .toList();
    if (items.isEmpty) return;
    final controllers = <String, TextEditingController>{
      for (final item in items) item['id'].toString(): TextEditingController(text: '0'),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terima Barang'),
        content: SizedBox(
          width: 520,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, i) {
              final item = items[i];
              final product = item['products'];
              final variant = item['product_variants'];
              final ordered = ((item['quantity'] ?? 0) as num).toInt();
              final received = ((item['received_quantity'] ?? 0) as num).toInt();
              return Row(
                children: [
                  Expanded(
                    child: Text(
                      '${product is Map ? product['name'] : '-'}${variant is Map ? ' • ${variant['name']}' : ''}\nSisa ${ordered - received}',
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: controllers[item['id'].toString()],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Terima'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Proses')),
        ],
      ),
    );
    if (ok == true) {
      final receipts = <Map<String, dynamic>>[];
      for (final item in items) {
        final q = int.tryParse(controllers[item['id'].toString()]!.text) ?? 0;
        final ordered = ((item['quantity'] ?? 0) as num).toInt();
        final received = ((item['received_quantity'] ?? 0) as num).toInt();
        if (q > 0) {
          if (q > ordered - received) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah penerimaan melebihi sisa PO.')));
            }
            for (final c in controllers.values) {
              c.dispose();
            }
            return;
          }
          receipts.add({'item_id': item['id'], 'quantity': q});
        }
      }
      try {
        await AdminOperationsRepository.instance.receivePurchaseOrder(widget.purchaseOrderId, receipts);
        if (mounted) await _refresh();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    for (final c in controllers.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Detail Purchase Order')),
        body: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) return Center(child: Text(friendlyError(snapshot.error!)));
            final po = snapshot.data![0] as Map<String, dynamic>;
            final products = snapshot.data![1] as List<Map<String, dynamic>>;
            final items = (po['purchase_order_items'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            final status = po['status']?.toString() ?? 'draft';
            final canEdit = ['draft', 'ordered', 'partial'].contains(status);
            final canReceive = items.isNotEmpty && ['draft', 'ordered', 'partial'].contains(status);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(po['po_number']?.toString() ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
                            _Status(label: status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Supplier: ${po['suppliers'] is Map ? (po['suppliers'] as Map)['name'] ?? '-' : '-'}'),
                        Text('Total: ${rupiah((po['total_cost'] ?? 0) as num)}'),
                        if (po['notes'] != null) Text('Catatan: ${po['notes']}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('Item PO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                      if (canEdit)
                        TextButton.icon(
                          onPressed: () => _addItem(po, products),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Item'),
                        ),
                    ],
                  ),
                  if (items.isEmpty)
                    const _Info(text: 'Belum ada item pada PO ini.')
                  else
                    ...items.map((item) {
                      final product = item['products'];
                      final variant = item['product_variants'];
                      return _Card(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${product is Map ? product['name'] : '-'}${variant is Map ? ' • ${variant['name']}' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            'Dipesan ${item['quantity']} • Diterima ${item['received_quantity']} • ${rupiah((item['unit_cost'] ?? 0) as num)}/unit',
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 14),
                  if (status == 'draft')
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _markOrdered,
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Tandai PO Dikirim ke Supplier'),
                    ),
                  if (canReceive) ...[
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : () => _receive(po),
                      icon: const Icon(Icons.inventory_rounded),
                      label: const Text('Terima Barang'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppTheme.border),
        ),
        child: child,
      );
}

class _Info extends StatelessWidget {
  const _Info({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: AppTheme.border),
        ),
        child: Text(text, style: const TextStyle(color: AppTheme.textSecondary)),
      );
}

class _Status extends StatelessWidget {
  const _Status({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFECEC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primary)),
      );
}
