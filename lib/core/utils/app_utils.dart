import 'dart:math';

import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

String rupiah(num value) => _rupiah.format(value);

String slugify(String value) {
  final lower = value.toLowerCase().trim();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
  return cleaned.replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'-+'), '-');
}

String newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-${hex.substring(20, 32)}';
}

String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('Invalid login credentials')) return 'Email atau password salah.';
  if (text.contains('Email not confirmed')) return 'Email belum dikonfirmasi.';
  if (text.contains('User already registered')) return 'Email sudah terdaftar.';
  if (text.contains('Stock not enough')) return 'Stok produk tidak mencukupi.';
  if (text.contains('Cart is empty')) return 'Keranjang masih kosong.';
  if (text.contains('Invalid order transition')) return 'Perubahan status pesanan tidak diizinkan.';
  if (text.contains('Stock adjustment reason is required')) return 'Isi alasan perubahan stok.';
  if (text.contains('Review is not allowed')) return 'Ulasan hanya dapat dibuat untuk produk yang sudah selesai dibeli.';
  if (text.contains('Return request already exists')) return 'Pengajuan retur untuk pesanan ini sudah ada.';
  if (text.contains('Return is not available')) return 'Pesanan ini belum dapat diajukan retur.';
  if (text.contains('Voucher')) return text.replaceFirst('Exception: ', '');
  return 'Terjadi kendala. Silakan coba lagi.';
}
