import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../shared/widgets/shop_shell.dart';

class ShopMartApp extends StatelessWidget {
  const ShopMartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shop Mart',
      theme: AppTheme.light,
      home: const ShopShell(),
    );
  }
}
