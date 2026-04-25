import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../providers/session_provider.dart';
import '../theme/app_theme.dart';

/// Premium animated splash with floating particles and logo reveal.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _particleController;
  bool _navigated = false;
  bool _timerElapsed = false;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (!mounted || _navigated) return;
      _timerElapsed = true;
      _tryNavigate();
    });
  }

  void _tryNavigate() {
    if (!mounted || _navigated || !_timerElapsed) return;

    final session = ref.read(sessionProvider);
    if (!session.isReady) return; // Will be called again via listener

    _navigated = true;
    if (!session.isLoggedIn) {
      context.go('/role-select');
      return;
    }

    context.go(session.isCaregiver ? '/dashboard' : '/child');
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // React to session state changes (e.g., when session finishes loading)
    ref.listen<SessionState>(sessionProvider, (_, __) => _tryNavigate());

    return Scaffold(
      body: Stack(
        children: [
          // ─── Background Gradient ────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4A3FCB), Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // ─── Floating Particles ────
          ...List.generate(15, (i) {
            final rng = Random(i);
            final startX = rng.nextDouble() * size.width;
            final startY = rng.nextDouble() * size.height;
            final pSize = 4.0 + rng.nextDouble() * 12;
            final opacity = 0.05 + rng.nextDouble() * 0.15;
            return AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) {
                final t = (_particleController.value + i * 0.07) % 1.0;
                return Positioned(
                  left: startX + sin(t * 2 * pi + i) * 30,
                  top: startY + cos(t * 2 * pi + i * 0.5) * 40 - t * 60,
                  child: Container(
                    width: pSize,
                    height: pSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: opacity),
                    ),
                  ),
                );
              },
            );
          }),

          // ─── Glossy ring accent ────
          Positioned(
            top: size.height * 0.15,
            right: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 2),
              ),
            ),
          ).animate().fadeIn(delay: 400.ms),

          Positioned(
            bottom: size.height * 0.2,
            left: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.06), Colors.transparent],
                ),
              ),
            ),
          ).animate().fadeIn(delay: 600.ms),

          // ─── Content ────
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo with glow
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                      radius: 0.8,
                    ),
                  ),
                  child: const Text('🌈', style: TextStyle(fontSize: 80)),
                )
                    .animate()
                    .fadeIn(duration: 800.ms)
                    .scale(
                      begin: const Offset(0.2, 0.2),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut,
                      duration: 1200.ms,
                    )
                    .shimmer(delay: 1200.ms, duration: 1500.ms, color: Colors.white24),

                const SizedBox(height: 28),

                // Title
                Text(
                  'Care & Child',
                  style: GoogleFonts.outfit(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 500.ms, duration: 700.ms).slideY(begin: 0.3, end: 0),

                const SizedBox(height: 6),

                // Subtitle with glass pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: AppTheme.pillRadius,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'AAC for Autism Support',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.5,
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms, duration: 600.ms),

                const SizedBox(height: 56),

                // Premium loader
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ).animate().fadeIn(delay: 1200.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
