import 'package:flutter_test/flutter_test.dart';

import 'package:coba_flutter/core/utils/app_utils.dart';

void main() {
  group('slugify', () {
    test('normalizes whitespace and punctuation', () {
      expect(slugify('  Gula Pasir Premium!!  '), 'gula-pasir-premium');
    });

    test('collapses repeated separators', () {
      expect(slugify('Produk   UMKM---Kerten'), 'produk-umkm-kerten');
    });
  });

  group('rupiah', () {
    test('formats integer currency without decimals', () {
      final value = rupiah(24000);
      expect(value.contains('24.000'), isTrue);
      expect(value.contains('Rp'), isTrue);
    });
  });

  group('friendlyError', () {
    test('does not expose raw login errors', () {
      expect(
        friendlyError(Exception('Invalid login credentials')),
        'Email atau password salah.',
      );
    });

    test('maps insufficient stock to customer-facing message', () {
      expect(
        friendlyError(Exception('Stock not enough')),
        'Stok produk tidak mencukupi.',
      );
    });

    test('falls back to generic message for unknown failures', () {
      expect(
        friendlyError(Exception('database internals should not leak')),
        'Terjadi kendala. Silakan coba lagi.',
      );
    });
  });
}
