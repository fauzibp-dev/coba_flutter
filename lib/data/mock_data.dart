import 'package:flutter/material.dart';

class ShopCategory {
  const ShopCategory({
    required this.name,
    required this.icon,
    required this.color,
  });

  final String name;
  final IconData icon;
  final Color color;
}

class Product {
  const Product({
    required this.name,
    required this.price,
    required this.oldPrice,
    required this.rating,
    required this.sold,
    required this.icon,
    required this.color,
    required this.category,
    required this.description,
    this.discountLabel,
  });

  final String name;
  final int price;
  final int oldPrice;
  final double rating;
  final String sold;
  final IconData icon;
  final Color color;
  final String category;
  final String description;
  final String? discountLabel;
}

class OrderSummary {
  const OrderSummary({
    required this.number,
    required this.productName,
    required this.total,
    required this.status,
    required this.statusColor,
  });

  final String number;
  final String productName;
  final int total;
  final String status;
  final Color statusColor;
}

const categories = <ShopCategory>[
  ShopCategory(name: 'Sembako', icon: Icons.rice_bowl_outlined, color: Color(0xFFFFE8E7)),
  ShopCategory(name: 'Minuman', icon: Icons.local_drink_outlined, color: Color(0xFFE6F4FF)),
  ShopCategory(name: 'Snack', icon: Icons.cookie_outlined, color: Color(0xFFFFF3D7)),
  ShopCategory(name: 'Rumah', icon: Icons.cleaning_services_outlined, color: Color(0xFFEAF6EA)),
  ShopCategory(name: 'Kopi & Teh', icon: Icons.coffee_outlined, color: Color(0xFFF4E9DF)),
  ShopCategory(name: 'Kebutuhan Bayi', icon: Icons.child_friendly_outlined, color: Color(0xFFF3E9FF)),
  ShopCategory(name: 'Perawatan', icon: Icons.spa_outlined, color: Color(0xFFE9F7F4)),
  ShopCategory(name: 'Lainnya', icon: Icons.grid_view_rounded, color: Color(0xFFF0F0F0)),
];

const products = <Product>[
  Product(
    name: 'Beras Premium Koperasi 5 Kg',
    price: 68000,
    oldPrice: 75000,
    rating: 4.9,
    sold: '1,2 rb',
    icon: Icons.rice_bowl_rounded,
    color: Color(0xFFF7E8D8),
    category: 'Sembako',
    description: 'Beras premium pilihan untuk kebutuhan rumah tangga. Dikemas bersih dan praktis oleh Koperasi Merah Putih Kerten.',
    discountLabel: '-9%',
  ),
  Product(
    name: 'Minyak Goreng Premium 1 Liter',
    price: 17500,
    oldPrice: 19500,
    rating: 4.8,
    sold: '842',
    icon: Icons.water_drop_outlined,
    color: Color(0xFFFFF0B8),
    category: 'Sembako',
    description: 'Minyak goreng untuk kebutuhan harian dengan kemasan 1 liter. Cocok untuk memasak, menggoreng, dan menumis.',
    discountLabel: '-10%',
  ),
  Product(
    name: 'Gula Pasir Kristal 1 Kg',
    price: 16500,
    oldPrice: 17500,
    rating: 4.9,
    sold: '621',
    icon: Icons.grain_rounded,
    color: Color(0xFFECECEC),
    category: 'Sembako',
    description: 'Gula pasir kristal bersih untuk minuman dan kebutuhan memasak sehari-hari.',
    discountLabel: '-6%',
  ),
  Product(
    name: 'Kopi Lokal Kerten Arabica 200 g',
    price: 42000,
    oldPrice: 48000,
    rating: 4.7,
    sold: '318',
    icon: Icons.coffee_rounded,
    color: Color(0xFFE8D8C7),
    category: 'Kopi & Teh',
    description: 'Kopi lokal dengan aroma kuat dan rasa seimbang. Cocok untuk manual brew maupun kopi tubruk.',
    discountLabel: '-12%',
  ),
  Product(
    name: 'Deterjen Cair Fresh 800 ml',
    price: 24500,
    oldPrice: 27000,
    rating: 4.8,
    sold: '455',
    icon: Icons.local_laundry_service_outlined,
    color: Color(0xFFDFF1FF),
    category: 'Rumah',
    description: 'Deterjen cair untuk mencuci pakaian dengan aroma segar dan mudah dibilas.',
    discountLabel: '-9%',
  ),
  Product(
    name: 'Paket Mi Instan Hemat 5 pcs',
    price: 15500,
    oldPrice: 17000,
    rating: 4.9,
    sold: '2 rb',
    icon: Icons.ramen_dining_rounded,
    color: Color(0xFFFFE0D6),
    category: 'Sembako',
    description: 'Paket hemat mi instan isi lima untuk stok kebutuhan cepat di rumah.',
    discountLabel: '-8%',
  ),
];

const orderSummaries = <OrderSummary>[
  OrderSummary(
    number: 'SM-20260921-000128',
    productName: 'Beras Premium Koperasi 5 Kg',
    total: 141000,
    status: 'Sedang Diproses',
    statusColor: Color(0xFFB26A00),
  ),
  OrderSummary(
    number: 'SM-20260918-000097',
    productName: 'Kopi Lokal Kerten Arabica 200 g',
    total: 42000,
    status: 'Selesai',
    statusColor: Color(0xFF2E7D32),
  ),
];

String rupiah(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final positionFromEnd = digits.length - i;
    buffer.write(digits[i]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
      buffer.write('.');
    }
  }
  return 'Rp$buffer';
}
