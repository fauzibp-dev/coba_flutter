import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  test('Indonesian date format is available for order and chat timestamps', () async {
    await initializeDateFormatting('id_ID');
    final date = DateTime(2026, 10, 12, 11, 3);
    expect(DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(date),
        '12 Okt 2026 • 11:03');
  });
}
