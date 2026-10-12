import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Export only the privacy-filtered fields already stored by the server.
class ClientErrorExport {
  static String formatOne(Map<String, dynamic> row) {
    String field(String key) => row[key]?.toString() ?? '-';
    return [
      'Log ID: ${field('id')}',
      'Waktu (UTC): ${field('created_at')}',
      'Severity: ${field('severity')}',
      'Sumber: ${field('source')}',
      'Halaman: ${field('screen')}',
      'Versi: KKMP Kerten 1.5.4',
      'Pengguna: ${field('user_id').substring(0, field('user_id').length < 8 ? field('user_id').length : 8)}...',
      'Pesan: ${field('message')}',
      'Stack trace:',
      field('stack_trace'),
    ].join('\n');
  }

  static String report(List<Map<String, dynamic>> rows) =>
      'KKMP KERTEN - ERROR LOG REPORT\nDibuat: ${DateTime.now().toUtc().toIso8601String()} UTC\n'
      'Jumlah: ${rows.length}\n\n'
      '${rows.map((r) => formatOne(r)).join('\n\n----------------------\n\n')}';

  static String _xml(String value) => value
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('"', '&quot;');

  static Future<void> share(List<Map<String, dynamic>> rows, String kind) async {
    if (rows.isEmpty) throw StateError('Tidak ada log untuk diekspor.');
    final text = report(rows);
    final temp = await getTemporaryDirectory();
    final name = 'kkmp_error_log_${DateTime.now().millisecondsSinceEpoch}';
    late final File file;

    if (kind == 'txt') {
      file = File('${temp.path}/$name.txt');
      await file.writeAsString(text, flush: true);
    } else if (kind == 'pdf') {
      final document = pw.Document();
      document.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        maxPages: 250,
        build: (_) => [
          pw.Header(level: 0, child: pw.Text('KKMP Kerten - Error Log')),
          pw.Text('Jumlah: ${rows.length}'),
          ...rows.map((row) => pw.Text(
            '\n-------------------\n${formatOne(row)}',
            style: const pw.TextStyle(fontSize: 8),
          )),
        ],
      ));
      file = File('${temp.path}/$name.pdf');
      await file.writeAsBytes(await document.save(), flush: true);
    } else if (kind == 'docx') {
      // Minimal valid Office Open XML document; no external templates.
      final xmlLines = text.split('\n').map((line) =>
          '<w:p><w:r><w:t xml:space="preserve">${_xml(line)}</w:t></w:r></w:p>').join();
      final archive = Archive();
      void add(String path, String xml) {
        final data = utf8.encode(xml);
        archive.addFile(ArchiveFile(path, data.length, data));
      }
      add('[Content_Types].xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '<Override PartName="/word/document.xml" '
          'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
          '</Types>');
      add('_rels/.rels',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '<Relationship Id="rId1" '
          'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
          'Target="word/document.xml"/></Relationships>');
      add('word/document.xml',
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
          '<w:body>$xmlLines<w:sectPr/></w:body></w:document>');
      file = File('${temp.path}/$name.docx');
      await file.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    } else {
      throw ArgumentError('Jenis ekspor tidak dikenal.');
    }
    await Share.shareXFiles([XFile(file.path)], text: 'Laporan error KKMP Kerten');
  }
}
