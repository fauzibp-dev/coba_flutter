import 'package:flutter_test/flutter_test.dart';

import 'package:coba_flutter/core/utils/app_utils.dart';

void main() {
  test('slugify membuat slug stabil untuk nama produk', () {
    expect(slugify('Beras Premium 5 Kg'), 'beras-premium-5-kg');
  });

  test('rupiah menghasilkan format mata uang Indonesia', () {
    expect(rupiah(10000).contains('10.000'), isTrue);
  });
}
