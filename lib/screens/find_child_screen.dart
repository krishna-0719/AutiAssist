import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/find_child_provider.dart';
import '../theme/app_theme.dart';

/// Find Child screen — location tracking with pulsing indicator & ping.
class FindChildScreen extends ConsumerWidget {
  const FindChildScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(findChildProvider);
    final loc = state.lastKnownLocation;
    final media = MediaQuery.of(context);
    final isTablet = media.size.width >= AppTheme.tabletBreakpoint;
    final padding = isTablet ? AppTheme.screenPaddingTablet : AppTheme.screenPaddingMobile;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('Find My Child',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              // ─── Location Hero Card ────
              Semantics(
                label: loc != null
                    ? 'Child located in ${loc.room}, ${loc.confidencePercent}% confidence, ${loc.timeAgo}'
                    : 'Child location unknown',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                  decoration: BoxDecoration(
                    gradient: AppTheme.coolGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.vibrantShadow,
                  ),
                  child: Column(
                    children: [
                      // Pulsing location icon
                      _PulsingLocationIcon(isActive: loc != null),
                      const SizedBox(height: 20),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          loc?.room ?? 'Unknown',
                          style: GoogleFonts.outfit(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (loc != null) ...[
                        _ConfidenceBadge(confidence: loc.confidencePercent),
                        const SizedBox(height: 6),
                        Text(
                          'Last seen: ${loc.timeAgo}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else
                        Text(
                          'Tap ping to locate child',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),

              const SizedBox(height: AppTheme.sectionSpacing),

              // ─── Ping Button ────
              Semantics(
                button: true,
                label: state.isPinging ? 'Pinging child device' : 'Ping child to find location',
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: state.isPinging
                        ? null
                        : () => ref.read(findChildProvider.notifier).findChildNow(),
                    icon: state.isPinging
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Icon(Icons.wifi_find_rounded, size: 24),
                    label: Text(
                      state.isPinging ? 'Pinging…' : '🔍 Ping Child Now',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.caregiverPing,
                      disabledBackgroundColor: AppTheme.caregiverPing.withValues(alpha: 0.6),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // ─── Continuous Tracking Toggle ────
              Container(
                padding: const EdgeInsets.all(AppTheme.cardPadding),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.softShadow,
                  border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.stream_rounded, color: AppTheme.success, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Tracking',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            state.continuousMode ? 'Streaming room changes' : 'Off',
                            style: const TextStyle(fontSize: 12, color: AppTheme.textMedium),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: state.continuousMode,
                      activeTrackColor: AppTheme.success,
                      onChanged: (val) =>
                          ref.read(findChildProvider.notifier).toggleContinuousTracking(val),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // ─── Info Cards ────
              if (loc != null) ...[
                _InfoCard(
                  icon: Icons.signal_wifi_4_bar_rounded,
                  label: 'Signal Strength',
                  value: loc.confidenceLabel,
                  color: _confidenceColor(loc.confidencePercent),
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                const SizedBox(height: 10),
                _InfoCard(
                  icon: Icons.access_time_rounded,
                  label: 'Last Updated',
                  value: loc.timeAgo,
                  color: AppTheme.caregiverPrimary,
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _confidenceColor(int pct) {
    if (pct >= 75) return AppTheme.success;
    if (pct >= 45) return AppTheme.caregiverWarning;
    return AppTheme.danger;
  }
}

// ─── Pulsing Location Icon ──────────────────────────────────────────

class _PulsingLocationIcon extends StatelessWidget {
  final bool isActive;
  const _PulsingLocationIcon({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
      ),
      child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 40),
    );

    if (!isActive) return icon;

    return icon
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.08, 1.08),
          duration: 1200.ms,
          curve: Curves.easeInOut,
        );
  }
}

// ─── Confidence Badge ───────────────────────────────────────────────

class _ConfidenceBadge extends StatelessWidget {
  final int confidence;
  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: AppTheme.pillRadius,
      ),
      child: Text(
        '$confidence% confidence',
        style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

// ─── Info Card ──────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _InfoCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textMedium),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
