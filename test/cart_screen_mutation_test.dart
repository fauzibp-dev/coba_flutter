import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coba_flutter/screens/cart_screen.dart';

class _FakeCart {
  int quantity = 1;
  int calls = 0;
  bool failSave = false;
  Completer<void>? hold;

  Future<List<Map<String, dynamic>>> load() async {
    if (quantity == 0) return [];
    return [
      {
        'id': 'cart-item-test',
        'quantity': quantity,
        'products': {
          'id': 'product-test',
          'name': 'Tes Produk',
          'price': 10000,
          'product_images': [],
        },
        'product_variants': null,
      },
    ];
  }

  Future<void> save(String itemId, int newQuantity) async {
    expect(itemId, 'cart-item-test');
    calls++;
    if (failSave) throw StateError('CART_NOT_SYNCED');
    if (hold != null) await hold!.future;
    quantity = newQuantity;
  }
}

Future<void> _showCart(WidgetTester tester, _FakeCart fake) async {
  await tester.pumpWidget(
    MaterialApp(
      home: CartScreen(loadItems: fake.load, saveQuantity: fake.save),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Keranjang: +, -, dan hapus mengubah kuantitas yang benar',
      (tester) async {
    final fake = _FakeCart();
    await _showCart(tester, fake);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Tambah jumlah Tes Produk'));
    await tester.pumpAndSettle();
    expect(fake.quantity, 2);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Kurangi jumlah Tes Produk'));
    await tester.pumpAndSettle();
    expect(fake.quantity, 1);
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus Tes Produk dari keranjang'));
    await tester.pumpAndSettle();
    expect(fake.quantity, 0);
    expect(fake.calls, 3);
    expect(find.text('Keranjang masih kosong'), findsOneWidget);
  });

  testWidgets('Error server terlihat dan produk tidak dianggap terubah',
      (tester) async {
    final fake = _FakeCart()..failSave = true;
    await _showCart(tester, fake);
    await tester.tap(find.bySemanticsLabel('Tambah jumlah Tes Produk'));
    await tester.pumpAndSettle();
    expect(fake.quantity, 1);
    expect(find.text('1'), findsOneWidget);
    expect(find.textContaining('Perubahan belum sesuai data server'), findsOneWidget);
  });

  testWidgets('Ketukan cepat saat permintaan berjalan tidak menumpuk RPC',
      (tester) async {
    final fake = _FakeCart()..hold = Completer<void>();
    await _showCart(tester, fake);
    await tester.tap(find.bySemanticsLabel('Tambah jumlah Tes Produk'));
    await tester.pump();
    // The second tap reaches a disabled control; it must not start a new RPC.
    await tester.tap(find.bySemanticsLabel('Tambah jumlah Tes Produk'));
    await tester.pump();
    expect(fake.calls, 1);

    fake.hold!.complete();
    await tester.pumpAndSettle();
    expect(fake.quantity, 2);
    expect(find.text('2'), findsOneWidget);
  });
}
