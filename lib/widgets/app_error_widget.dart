import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Error widget shown when the app encounters a critical startup failure.
///
/// This MUST be wrapped in a MaterialApp so it has a valid MediaQuery ancestor.
/// Used as: runApp(const AppErrorWidget(message: 'Config missing'));
class AppErrorWidget extends StatelessWidget {
  final String? message;
  final FlutterErrorDetails? details;

  const AppErrorWidget({super.key, this.message, this.details});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline_rounded,
                      size: 56, color: AppTheme.danger),
                ),
                const SizedBox(height: 24),
                Text(
                  'Something went wrong',
                  style: GoogleFonts.outfit(
                      fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                Text(
                  message ?? details?.exceptionAsString() ?? 'An unexpected error occurred.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppTheme.textMedium,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Please restart the app.\nIf the problem persists, reinstall.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
