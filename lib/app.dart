import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/home_shell.dart';
import 'services/commerce_repository.dart';

class ShopMartApp extends StatefulWidget {
  const ShopMartApp({super.key});

  @override
  State<ShopMartApp> createState() => _ShopMartAppState();
}

class _ShopMartAppState extends State<ShopMartApp> {
  static const _currentVersion = '1.5.0';
  late Future<Map<String, dynamic>> _settings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => _settings = CommerceRepository.instance.publicAppSettings();

  bool _versionLowerThan(String current, String minimum) {
    List<int> parts(String value) => value
        .split('.')
        .take(3)
        .map((e) => int.tryParse(e.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final a = parts(current);
    final b = parts(minimum);
    while (a.length < 3) a.add(0);
    while (b.length < 3) b.add(0);
    for (var i = 0; i < 3; i++) {
      if (a[i] < b[i]) return true;
      if (a[i] > b[i]) return false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Mart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: FutureBuilder<Map<String, dynamic>>(
        future: _settings,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _StartupScreen();
          }
          // Availability of the public storefront must not depend on the
          // settings endpoint. If it is temporarily unavailable, normal app
          // error handling inside each screen still applies.
          if (snapshot.hasError || !snapshot.hasData) return const HomeShell();

          final values = snapshot.data!;
          final maintenance = values['maintenance'];
          if (maintenance is Map && maintenance['enabled'] == true) {
            return _ReleaseGateScreen(
              icon: Icons.engineering_rounded,
              title: 'Shop Mart sedang dipelihara',
              message: maintenance['message']?.toString() ??
                  'Layanan sedang dalam pemeliharaan. Silakan coba beberapa saat lagi.',
              actionLabel: 'Coba lagi',
              onAction: () => setState(_reload),
            );
          }

          final minimum = values['minimum_supported_version'];
          final minAndroid = minimum is Map ? minimum['android']?.toString() : null;
          if (minAndroid != null && _versionLowerThan(_currentVersion, minAndroid)) {
            return _ReleaseGateScreen(
              icon: Icons.system_update_rounded,
              title: 'Pembaruan diperlukan',
              message:
                  'Versi Shop Mart ini sudah tidak didukung. Perbarui aplikasi sebelum melanjutkan.',
              actionLabel: 'Periksa lagi',
              onAction: () => setState(_reload),
            );
          }
          return const HomeShell();
        },
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_rounded, size: 54, color: AppTheme.primary),
              SizedBox(height: 16),
              SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
            ],
          ),
        ),
      );
}

class _ReleaseGateScreen extends StatelessWidget {
  const _ReleaseGateScreen({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 62, color: AppTheme.primary),
                    const SizedBox(height: 16),
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary, height: 1.5)),
                    const SizedBox(height: 20),
                    FilledButton(onPressed: onAction, child: Text(actionLabel)),
                    const SizedBox(height: 12),
                    const Text('Shop Mart v1.5.0', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
