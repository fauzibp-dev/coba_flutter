import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/supabase_config.dart';
import 'services/client_error_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ClientErrorReporter.instance.record(details.exception,
        trace: details.stack, source: 'flutter_framework',
        screen: details.context?.toString() ?? '');
  };
  PlatformDispatcher.instance.onError = (error, trace) {
    ClientErrorReporter.instance.record(error,
        trace: trace, source: 'platform_uncaught');
    return true;
  };
  ErrorWidget.builder = (details) => Material(
    color: const Color(0xFFFFF5F5),
    child: Center(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text('Tampilan mengalami kendala. Silakan kembali dan buka lagi.\n'
          '${details.exceptionAsString()}',
          textAlign: TextAlign.center,
          maxLines: 6, overflow: TextOverflow.ellipsis),
    )),
  );
  // Orders and chat use Indonesian date symbols in DateFormat.
  await initializeDateFormatting('id_ID');
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  Supabase.instance.client.auth.onAuthStateChange.listen((state) {
    if (state.session != null) unawaited(ClientErrorReporter.instance.flush());
  });
  unawaited(ClientErrorReporter.instance.flush());
  runApp(const ShopMartApp());
}
