import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coba_flutter/core/theme/app_theme.dart';

void main() {
  testWidgets('Voucher button fits a narrow horizontal row', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: SafeArea(child: Row(children: [
        const Expanded(child: TextField()),
        const SizedBox(width: 8),
        FilledButton.tonal(onPressed: () {}, child: const Text('Terapkan')),
      ]))),
    ));
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FilledButton)).width, lessThan(320));
  });
}
