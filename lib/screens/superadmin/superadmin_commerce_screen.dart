import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/superadmin_commerce_repository.dart';
import '../../services/superadmin_repository.dart';

class SuperadminCommerceScreen extends StatefulWidget {
  const SuperadminCommerceScreen({super.key});

  @override
  State<SuperadminCommerceScreen> createState() => _SuperadminCommerceScreenState();
}

class _SuperadminCommerceScreenState extends State<SuperadminCommerceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Future<List<dynamic>> _future;
  String? _storeId;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    _future = Future.wait([
      SuperadminCommerceRepository.instance.analytics(days: _days),
      SuperadminCommerceRepository.instance.campaigns(storeId: _storeId),
      SuperadminRepository.instance.stores(),
      SuperadminCommerceRepository.instance.accountDeletionRequests(),
    ]);
  }

  Future<void> _refresh() async { setState(_reload); await _future; }

  Future<void> _editCampaign(Map<String, dynamic>? campaign, List<Map<String, dynamic>> stores) async {
    if (stores.isEmpty) return;
    var storeId = campaign?['store_id']?.toString() ?? _storeId ?? stores.first['id'].toString();
    final name = TextEditingController(text: campaign?['name']?.toString() ?? '');
    final priority = TextEditingController(text: '${campaign?['priority'] ?? 0}');
    var type = campaign?['campaign_type']?.toString() ?? 'flash_sale';
    var status = campaign?['status']?.toString() ?? 'draft';
    var start = DateTime.tryParse(campaign?['starts_at']?.toString() ?? '')?.toLocal() ?? DateTime.now();
    DateTime? end = DateTime.tryParse(campaign?['ends_at']?.toString() ?? '')?.toLocal();
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(campaign == null ? 'Tambah Campaign' : 'Edit Campaign'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                  initialValue: storeId,
                  decoration: const InputDecoration(labelText: 'Toko'),
                  items: stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-'))).toList(),
                  onChanged: campaign == null ? (v) => setDialogState(() => storeId = v ?? storeId) : null,
                ),
                const SizedBox(height: 10),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama campaign')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(value: 'flash_sale', child: Text('Flash Sale')),
                    DropdownMenuItem(value: 'auto_discount', child: Text('Auto Discount')),
                    DropdownMenuItem(value: 'featured', child: Text('Featured')),
                    DropdownMenuItem(value: 'category_promo', child: Text('Promo Kategori')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const ['draft','active','paused','ended'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
                  onChanged: (v) => setDialogState(() => status = v ?? status),
                ),
                const SizedBox(height: 10),
                TextField(controller: priority, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Priority')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () async { final d = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: start); if (d != null) setDialogState(() => start = DateTime(d.year,d.month,d.day,start.hour,start.minute)); }, child: Text('Mulai ${start.day}/${start.month}/${start.year}'))),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(onPressed: () async { final d = await showDatePicker(context: context, firstDate: start, lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: end ?? start.add(const Duration(days: 1))); if (d != null) setDialogState(() => end = DateTime(d.year,d.month,d.day,23,59)); }, child: Text(end == null ? 'Tanggal selesai' : 'Selesai ${end!.day}/${end!.month}/${end!.year}'))),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(context, name.text.trim().isNotEmpty), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (changed == true) {
      try {
        await SuperadminCommerceRepository.instance.saveCampaign(id: campaign?['id']?.toString(), storeId: storeId, name: name.text, type: type, status: status, startsAt: start, endsAt: end, priority: int.tryParse(priority.text) ?? 0);
        if (mounted) setState(_reload);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    name.dispose(); priority.dispose();
  }

  Future<void> _addCampaignProduct(Map<String, dynamic> campaign) async {
    final products = await SuperadminCommerceRepository.instance.storeProducts(campaign['store_id'].toString());
    if (!mounted || products.isEmpty) return;
    String productId = products.first['id'].toString();
    String? variantId;
    final price = TextEditingController();
    final quota = TextEditingController();
    final perUser = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final product = products.firstWhere((p) => p['id'].toString() == productId);
          final variants = (product['product_variants'] as List? ?? []).map((e) => Map<String,dynamic>.from(e as Map)).where((v) => v['is_active'] == true).toList();
          return AlertDialog(
            title: const Text('Produk Campaign'),
            content: SingleChildScrollView(
              child: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(initialValue: productId, decoration: const InputDecoration(labelText: 'Produk'), items: products.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name']?.toString() ?? '-'))).toList(), onChanged: (v) => setDialogState(() { productId = v ?? productId; variantId = null; })),
                const SizedBox(height: 10),
                if (variants.isNotEmpty) DropdownButtonFormField<String?>(initialValue: variantId, decoration: const InputDecoration(labelText: 'Varian (opsional)'), items: [const DropdownMenuItem<String?>(value: null, child: Text('Semua / produk utama')), ...variants.map((v) => DropdownMenuItem<String?>(value: v['id'].toString(), child: Text(v['name']?.toString() ?? '-')))], onChanged: (v) => setDialogState(() => variantId = v)),
                if (variants.isNotEmpty) const SizedBox(height: 10),
                TextField(controller: price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Harga promo')),
                const SizedBox(height: 10),
                Row(children: [Expanded(child: TextField(controller: quota, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quota'))), const SizedBox(width: 8), Expanded(child: TextField(controller: perUser, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Limit/user')))]),
              ])),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
              FilledButton(onPressed: () => Navigator.pop(context, (num.tryParse(price.text) ?? -1) >= 0), child: const Text('Simpan')),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      try {
        await SuperadminCommerceRepository.instance.upsertCampaignProduct(campaignId: campaign['id'] as String, productId: productId, variantId: variantId, promoPrice: num.parse(price.text), quota: int.tryParse(quota.text), perUserLimit: int.tryParse(perUser.text));
        if (mounted) setState(_reload);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
    price.dispose(); quota.dispose(); perUser.dispose();
  }

  Future<void> _maintenance() async {
    var enabled = false;
    final message = TextEditingController(text: 'KKMP Kerten sedang dalam pemeliharaan. Silakan coba beberapa saat lagi.');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
        title: const Text('Maintenance Mode'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktifkan maintenance'), value: enabled, onChanged: (v) => setDialogState(() => enabled = v)),
          TextField(controller: message, maxLines: 3, decoration: const InputDecoration(labelText: 'Pesan pengguna')),
        ]),
        actions: [TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Batal')), FilledButton(onPressed: () => Navigator.pop(context,true), child: const Text('Simpan'))],
      )),
    );
    if (ok == true) await SuperadminCommerceRepository.instance.updateAppSetting('maintenance', {'enabled': enabled, 'message': message.text}, isPublic: true);
    message.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Commerce Control Center', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(tooltip: 'Maintenance', onPressed: _maintenance, icon: const Icon(Icons.engineering_outlined))],
          bottom: TabBar(controller: _tabs, isScrollable: true, tabs: const [Tab(text: 'Analytics'), Tab(text: 'Campaign'), Tab(text: 'Privacy Queue')]),
        ),
        body: FutureBuilder<List<dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Gagal memuat commerce control: ${friendlyError(snapshot.error!)}'));
            final analytics = snapshot.data![0] as Map<String,dynamic>;
            final campaigns = snapshot.data![1] as List<Map<String,dynamic>>;
            final stores = snapshot.data![2] as List<Map<String,dynamic>>;
            final deletions = snapshot.data![3] as List<Map<String,dynamic>>;
            return TabBarView(controller: _tabs, children: [
              _AnalyticsTab(data: analytics, days: _days, onDays: (v) => setState(() { _days = v; _reload(); })),
              Column(children: [
                Padding(padding: const EdgeInsets.fromLTRB(16,12,16,6), child: DropdownButtonFormField<String>(initialValue: _storeId ?? '_all', decoration: const InputDecoration(labelText: 'Filter toko'), items: [const DropdownMenuItem(value: '_all', child: Text('Semua toko')), ...stores.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['name']?.toString() ?? '-')))], onChanged: (v) => setState(() { _storeId = v == '_all' ? null : v; _reload(); }))),
                Expanded(child: RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
                  Row(children: [const Expanded(child: Text('Campaign & Flash Sale', style: TextStyle(fontSize: 17,fontWeight: FontWeight.w900))), FilledButton.tonalIcon(onPressed: stores.isEmpty ? null : () => _editCampaign(null,stores), icon: const Icon(Icons.add), label: const Text('Campaign'))]),
                  const SizedBox(height: 10),
                  if (campaigns.isEmpty) const Text('Belum ada campaign.'),
                  ...campaigns.map((c) {
                    final items = (c['campaign_products'] as List? ?? []);
                    return _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(c['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w900))), _Badge(c['status']?.toString() ?? '-')]),
                      const SizedBox(height: 4),
                      Text('${c['campaign_type']} • ${c['stores'] is Map ? (c['stores'] as Map)['name'] : '-'} • ${items.length} produk', style: const TextStyle(fontSize: 12,color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Wrap(spacing: 7, children: [OutlinedButton(onPressed: () => _editCampaign(c,stores), child: const Text('Edit')), FilledButton.tonal(onPressed: () => _addCampaignProduct(c), child: const Text('Tambah Produk'))]),
                      if (items.isNotEmpty) ...[const Divider(height: 20), ...items.take(8).map((raw) { final item = raw as Map; final p = item['products'] as Map?; return Padding(padding: const EdgeInsets.only(bottom: 5), child: Text('${p?['name'] ?? '-'} • ${rupiah((item['promo_price'] ?? 0) as num)} • ${item['sold_qty'] ?? 0}/${item['quota'] ?? '∞'}', style: const TextStyle(fontSize: 12))); })],
                    ]));
                  }),
                ]))),
              ]),
              RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text('Permintaan Privasi', style: TextStyle(fontSize: 17,fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                if (deletions.isEmpty) const Text('Belum ada permintaan penghapusan akun.'),
                ...deletions.map((d) => _Card(child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.privacy_tip_outlined), title: Text((d['profiles'] is Map ? (d['profiles'] as Map)['full_name'] : null)?.toString() ?? d['user_id'].toString().substring(0,8), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${d['status']} • ${d['reason'] ?? 'Tanpa alasan'}\n${d['requested_at'] ?? ''}')))),
              ])),
            ]);
          },
        ),
      );
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.data,required this.days,required this.onDays});
  final Map<String,dynamic> data;
  final int days;
  final ValueChanged<int> onDays;
  @override
  Widget build(BuildContext context) {
    final top = (data['top_products'] as List? ?? []).map((e) => Map<String,dynamic>.from(e as Map)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [const Expanded(child: Text('Business Analytics', style: TextStyle(fontSize:18,fontWeight: FontWeight.w900))), DropdownButton<int>(value: days, items: const [7,30,90,365].map((d) => DropdownMenuItem(value:d,child:Text('$d hari'))).toList(), onChanged: (v) { if(v!=null) onDays(v); })]),
      const SizedBox(height: 12),
      GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,childAspectRatio:1.7,crossAxisSpacing:8,mainAxisSpacing:8,children:[
        _Metric('Revenue',rupiah((data['revenue'] ?? 0) as num)), _Metric('Order','${data['orders'] ?? 0}'), _Metric('AOV',rupiah((data['aov'] ?? 0) as num)), _Metric('Customer','${data['customers'] ?? 0}'), _Metric('Selesai','${data['completed'] ?? 0}'), _Metric('Batal','${data['cancelled'] ?? 0}'), _Metric('Retur','${data['return_count'] ?? 0}'), _Metric('Low Stock','${data['low_stock'] ?? 0}'),
      ]),
      const SizedBox(height:18), const Text('Produk Terlaris',style:TextStyle(fontWeight:FontWeight.w900,fontSize:16)), const SizedBox(height:8),
      if(top.isEmpty) const Text('Belum ada data penjualan.') else ...top.map((p)=>_Card(child:Row(children:[Expanded(child:Text(p['product_name']?.toString()??'-',style:const TextStyle(fontWeight:FontWeight.w700))),Text('${p['qty']} • ${rupiah((p['sales']??0) as num)}')]))),
    ]);
  }
}

class _Metric extends StatelessWidget { const _Metric(this.label,this.value); final String label,value; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10),border:Border.all(color:AppTheme.border)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Text(label,style:const TextStyle(fontSize:11,color:AppTheme.textSecondary)),const SizedBox(height:3),Text(value,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16))])); }
class _Card extends StatelessWidget { const _Card({required this.child}); final Widget child; @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(11),border:Border.all(color:AppTheme.border)),child:child); }
class _Badge extends StatelessWidget { const _Badge(this.text); final String text; @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:const Color(0xFFFFECEC),borderRadius:BorderRadius.circular(20)),child:Text(text,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700,color:AppTheme.primary))); }
