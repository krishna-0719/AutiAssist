import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router.dart';
import 'services/config_service.dart';
import 'services/local_db_service.dart';
import 'services/tts_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_logger.dart';
import 'widgets/app_error_widget.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ─── Custom error boundary ──────────────
    FlutterError.onError = (details) {
      AppLogger.error(
        'Flutter framework error',
        error: details.exception,
        stackTrace: details.stack,
        tag: 'FLUTTER',
      );
    };

    // ─── Validate configuration ──────────────
    try {
      ConfigService.validate();
    } catch (e) {
      AppLogger.error('Config validation failed: $e', tag: 'CONFIG');
      runApp(AppErrorWidget(message: e.toString()));
      return;
    }

    // ─── Initialize services ─────────────────
    await LocalDbService.init();

    await Supabase.initialize(
      url: ConfigService.supabaseUrl,
      anonKey: ConfigService.supabaseAnonKey,
    );
    AppLogger.info('Supabase initialized', tag: 'INIT');

    await TtsService.init();
    AppLogger.info('App initialized successfully', tag: 'INIT');

    // ─── Replace error widget globally ───────
    ErrorWidget.builder = (details) => AppErrorWidget(details: details);

    runApp(const ProviderScope(child: CareChildApp()));
  }, (error, stackTrace) {
    AppLogger.error(
      'Uncaught zone error',
      error: error,
      stackTrace: stackTrace,
      tag: 'ZONE',
    );
  });
}

/// Root application widget.
class CareChildApp extends ConsumerWidget {
  const CareChildApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Care & Child AAC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
