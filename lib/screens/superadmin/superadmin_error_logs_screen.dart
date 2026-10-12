import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../services/client_error_export.dart';
import '../../services/client_error_reporter.dart';

/// Only Super Admin can read rows: enforced by PostgreSQL RLS.
class SuperadminErrorLogsScreen extends StatefulWidget {
  const SuperadminErrorLogsScreen({super.key});
  @override
  State<SuperadminErrorLogsScreen> createState() => _SuperadminErrorLogsScreenState();
}

class _SuperadminErrorLogsScreenState extends State<SuperadminErrorLogsScreen> {
  late Future<List<Map<String, dynamic>>> _future;
  String _severity = 'all';

  @override
  void initState() { super.initState(); _reload(); }

  void _reload() {
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await Supabase.instance.client
        .from('client_error_logs')
        .select('id,created_at,user_id,severity,source,screen,message,stack_trace,app_version,platform,fingerprint')
        .order('created_at', ascending: false).limit(150)
        .timeout(const Duration(seconds: 18));
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  List<Map<String, dynamic>> _filtered(List<Map<String, dynamic>> rows) =>
      _severity == 'all' ? rows :
      rows.where((r) => r['severity'] == _severity).toList();

  Future<void> _export(List<Map<String, dynamic>> rows, String extension) async {
    try {
      await ClientErrorExport.share(rows, extension);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ekspor gagal: ${friendlyError(error)}')));
    }
  }

  Future<void> _copy(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log berhasil disalin.')));
  }

  Future<void> _testLog() async {
    ClientErrorReporter.instance.record(
      StateError('Diagnostic test from KKMP Kerten Error Log Center'),
      source: 'diagnostic_test', screen: 'Super Admin / Error Logs',
    );
    await ClientErrorReporter.instance.flush();
    if (mounted) setState(_reload);
  }

  void _details(Map<String, dynamic> row) {
    final data = ClientErrorExport.formatOne(row);
    showDialog<void>(context: context, builder: (context) => AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      title: const Text('Detail Error'),
      content: SizedBox(
        width: 520,
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: SingleChildScrollView(child: SelectableText(data,
          style: const TextStyle(fontSize: 12, height: 1.5))),
      ),
      actions: [
        TextButton.icon(onPressed: () => _copy(data),
          icon: const Icon(Icons.copy), label: const Text('Salin')),
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Tutup')),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Error Log Center'),
      actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Muat ulang',
          onPressed: () => setState(_reload)),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('Tidak bisa memuat log: ${friendlyError(snapshot.error!)}',
                textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => setState(_reload),
                child: const Text('Coba lagi')),
            ]),
          ));
        }

        final records = _filtered(snapshot.data ?? []);
        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Terbaru: ${records.length} dari maksimal 150 catatan',
                style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Log yang tertangkap saat aplikasi berjalan. Tidak mencakup '
                'crash native sebelum Flutter atau kejadian offline yang belum terkirim.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final option in const ['all', 'error', 'fatal', 'warning'])
                    ChoiceChip(label: Text(option == 'all' ? 'Semua' : option),
                      selected: _severity == option,
                      onSelected: (_) => setState(() => _severity = option)),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_all, size: 17),
                    label: const Text('Salin'),
                    onPressed: records.isEmpty ? null :
                      () => _copy(ClientErrorExport.report(records)),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Simpan atau bagikan log',
                    enabled: records.isNotEmpty,
                    onSelected: (kind) => _export(records, kind),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'txt', child: Text('Simpan TXT')),
                      PopupMenuItem(value: 'docx', child: Text('Simpan Word (.docx)')),
                      PopupMenuItem(value: 'pdf', child: Text('Simpan PDF')),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.all(9),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.file_download_outlined),
                        SizedBox(width: 5), Text('Ekspor'),
                      ]),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _testLog, icon: const Icon(Icons.bug_report_outlined),
                label: const Text('Uji pencatatan log'),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: records.isEmpty
              ? const Center(child: Text('Belum ada error yang tercatat.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final row = records[i];
                    final severity = row['severity']?.toString() ?? 'error';
                    final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
                    return Card(child: ListTile(
                      onTap: () => _details(row),
                      leading: Icon(
                        severity == 'fatal' ? Icons.dangerous_outlined : Icons.bug_report_outlined,
                        color: AppTheme.error),
                      title: Text(row['message']?.toString() ?? '-',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${row['source'] ?? '-'} • '
                        '${date?.toLocal().toString().substring(0, 19) ?? '-'}',
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                    ));
                  },
                ),
          ),
        ]);
      },
    ),
  );
}
