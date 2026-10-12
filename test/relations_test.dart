import 'package:flutter_test/flutter_test.dart';
import 'package:coba_flutter/core/utils/relations.dart';

void main() {
  group('embedded Supabase relationships', () {
    test('one-to-one payload is normalized into a list', () {
      expect(relationRows({'id': 'shipment-1'}), [{'id': 'shipment-1'}]);
    });
    test('one-to-many payload remains a list', () {
      expect(relationRows([{'id': 'a'}, {'id': 'b'}]).length, 2);
    });
    test('null relationship returns no rows', () {
      expect(relationRows(null), isEmpty);
    });
    test('unexpected scalar fails explicitly', () {
      expect(() => relationRows(123), throwsFormatException);
    });
  });
}
