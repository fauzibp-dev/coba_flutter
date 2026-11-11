import '../../services/client_error_reporter.dart';
import 'package:intl/intl.dart';

final _rupiah = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0);

String rupiah(num value) => _rupiah.format(value);

String slugify(String value) {
  final lower = value.toLowerCase().trim();
  final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\s-]'), '');
  return cleaned.replaceAll(RegExp(r'\s+'), '-').replaceAll(RegExp(r'-+'), '-');
}

String friendlyError(Object error) {
  ClientErrorReporter.instance.record(error, trace: StackTrace.current);
  final text = error.toString();
  if (text.contains('Invalid login credentials')) return 'Email atau password salah.';
  if (text.contains('Email not confirmed')) return 'Email belum dikonfirmasi.';
  if (text.contains('User already registered')) return 'Email sudah terdaftar.';
  if (text.contains('Stock not enough')) return 'Stok produk tidak mencukupi.';
  if (text.contains('Cart item not found')) return 'Produk di keranjang sudah berubah atau terhapus. Keranjang akan dimuat ulang.';
  if (text.contains('CART_NOT_SYNCED')) return 'Perubahan belum sesuai data server. Keranjang dimuat ulang.';
  if (text.contains('Cart is empty')) return 'Keranjang masih kosong.';
  if (text.contains('Voucher')) return text.replaceFirst('Exception: ', '');
  return 'Terjadi kendala. Silakan coba lagi.';
}
