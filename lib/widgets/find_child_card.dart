import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/child_location.dart';
import '../providers/find_child_provider.dart';
import '../theme/app_theme.dart';

/// Premium Find My Child card with glassmorphism for the dashboard.
class FindChildCard extends ConsumerWidget {
  const FindChildCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final findState = ref.watch(findChildProvider);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF8F9FF), Color(0xFFF0F4FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppTheme.coloredShadow(AppTheme.primary),
                ),
                child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text('Find My Child',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    if (findState.continuousMode)
                      Row(
                        children: [
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.success),
                          ),
                          const SizedBox(width: 4),
                          const Text('Live tracking',
                              style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w700)),
                        ],
                      ),
                  ],
                ),
              ),
              // Live toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: findState.continuousMode
                      ? AppTheme.success.withValues(alpha: 0.1)
                      : AppTheme.textLight.withValues(alpha: 0.1),
                  borderRadius: AppTheme.pillRadius,
                  border: Border.all(
                    color: findState.continuousMode
                        ? AppTheme.success.withValues(alpha: 0.3)
                        : Colors.transparent),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Live',
                        style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800,
                          color: findState.continuousMode ? AppTheme.success : AppTheme.textLight)),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: findState.continuousMode,
                        activeThumbColor: AppTheme.success,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: (val) => ref.read(findChildProvider.notifier).toggleContinuousTracking(val),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Location display
          if (findState.lastKnownLocation != null)
            _buildLocationInfo(findState.lastKnownLocation!)
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: AppTheme.inputRadius,
                border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.textLight, size: 18),
                  SizedBox(width: 10),
                  Text('Tap "Ping" to locate your child',
                      style: TextStyle(color: AppTheme.textMedium, fontSize: 13)),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Gradient Ping button
          GestureDetector(
            onTap: findState.isPinging
                ? null
                : () => ref.read(findChildProvider.notifier).findChildNow(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: findState.isPinging ? AppTheme.darkGradient : AppTheme.coolGradient,
                borderRadius: AppTheme.inputRadius,
                boxShadow: findState.isPinging ? [] : AppTheme.coloredShadow(AppTheme.accent),
              ),
              child: Center(
                child: findState.isPinging
                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Pinging...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ])
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.wifi_find_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text('🔍  Ping Child', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo(ChildLocation loc) {
    final confColor = loc.confidence >= 0.75
        ? AppTheme.success
        : loc.confidence >= 0.45
            ? AppTheme.warning
            : AppTheme.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.inputRadius,
        border: Border.all(color: confColor.withValues(alpha: 0.2)),
        boxShadow: AppTheme.coloredShadow(confColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: confColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.room_rounded, color: confColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(loc.room,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${loc.confidencePercent}% confidence • ${loc.timeAgo}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMedium)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05);
  }
}
