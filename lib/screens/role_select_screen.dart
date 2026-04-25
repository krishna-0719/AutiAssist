import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Premium role selection with glassmorphic cards.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ─── Gradient Background ────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF4F6FB), Color(0xFFE8EDF2), Color(0xFFF0E6FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          // ─── Decorative Blobs ────
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.secondary.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ─── Content ────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: const Text('🌈', style: TextStyle(fontSize: 56)),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 900.ms),

                  const SizedBox(height: 28),

                  Text(
                    'Care & Child',
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppTheme.textDark,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 6),

                  Text(
                    'Who is using this device?',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: AppTheme.textMedium,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const Spacer(flex: 1),

                  // ─── Child Card ────
                  Semantics(
                    button: true,
                    label: 'Select child role to tap symbols and communicate',
                    child: _GlassRoleCard(
                      emoji: '👶',
                      title: "I'm the Child",
                      subtitle: 'Tap symbols to communicate',
                      gradient: AppTheme.coolGradient,
                      onTap: () => context.go('/child-join'),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2),

                  const SizedBox(height: 18),

                  // ─── Caregiver Card ────
                  Semantics(
                    button: true,
                    label: 'Select caregiver role to manage, track, and respond',
                    child: _GlassRoleCard(
                      emoji: '👨‍👩‍👧',
                      title: "I'm the Caregiver",
                      subtitle: 'Manage, track, and respond',
                      gradient: AppTheme.purpleGradient,
                      onTap: () => context.go('/caregiver-signin'),
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.2),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassRoleCard extends StatefulWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _GlassRoleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  State<_GlassRoleCard> createState() => _GlassRoleCardState();
}

class _GlassRoleCardState extends State<_GlassRoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isHovered = true),
      onTapUp: (_) {
        setState(() => _isHovered = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: AppTheme.cardRadius,
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(alpha: 0.35),
                blurRadius: _isHovered ? 28 : 20,
                offset: const Offset(0, 8),
                spreadRadius: _isHovered ? 2 : -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: AppTheme.cardRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
              child: Row(
                children: [
                  // Emoji in glass circle
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(widget.emoji, style: const TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
