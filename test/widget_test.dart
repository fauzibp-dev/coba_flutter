import 'package:flutter_test/flutter_test.dart';

import 'package:coba_flutter/core/utils/app_utils.dart';

void main() {
  test('slugify membuat slug stabil untuk nama produk', () {
    expect(slugify('Beras Premium 5 Kg'), 'beras-premium-5-kg');
  });

  test('rupiah menghasilkan format mata uang Indonesia', () {
    expect(rupiah(10000).contains('10.000'), isTrue);
  });

  test('newRequestId menghasilkan UUID v4 valid dan unik', () {
    final first = newRequestId();
    final second = newRequestId();
    final uuidV4 = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );
    expect(uuidV4.hasMatch(first), isTrue);
    expect(uuidV4.hasMatch(second), isTrue);
    expect(first, isNot(second));
  });

  test('friendlyError memetakan kegagalan stok dan order', () {
    expect(friendlyError(Exception('Stock not enough')), 'Stok produk tidak mencukupi.');
    expect(
      friendlyError(Exception('Invalid order transition from paid to shipped')),
      'Perubahan status pesanan tidak diizinkan.',
    );
  });
}
