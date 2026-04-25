import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';

/// Premium symbol card with glassmorphism, glow effect, and press animation.
class SymbolCard extends StatefulWidget {
  final String label;
  final String emoji;
  final String? imageUrl;
  final VoidCallback onTap;
  final Color? accentColor;
  final bool isSuggested;
  final bool compact;

  const SymbolCard({
    super.key,
    required this.label,
    required this.emoji,
    this.imageUrl,
    required this.onTap,
    this.accentColor,
    this.isSuggested = false,
    this.compact = false,
  });

  @override
  State<SymbolCard> createState() => _SymbolCardState();
}

class _SymbolCardState extends State<SymbolCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _pressController.forward();
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
    setState(() => _isPressed = false);
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _handleTapCancel() {
    _pressController.reverse();
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageUrl != null && widget.imageUrl!.isNotEmpty;
    final accent = widget.accentColor ?? AppTheme.primary;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isPressed
                ? accent.withValues(alpha: 0.08)
                : (widget.isSuggested ? AppTheme.warning.withValues(alpha: 0.05) : Colors.white),
            borderRadius: AppTheme.cardRadius,
            border: Border.all(
              color: _isPressed
                  ? accent.withValues(alpha: 0.4)
                  : (widget.isSuggested ? AppTheme.warning.withValues(alpha: 0.8) : AppTheme.cardBorder.withValues(alpha: 0.5)),
              width: _isPressed ? 2 : (widget.isSuggested ? 2 : 1),
            ),
            boxShadow: _isPressed
                ? AppTheme.coloredShadow(accent)
                : (widget.isSuggested ? AppTheme.coloredShadow(AppTheme.warning) : AppTheme.softShadow),
          ),
          child: ClipRRect(
            borderRadius: AppTheme.cardRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Stack(
                children: [
                  // Subtle gradient shimmer overlay
                  Positioned(
                    top: -20,
                    right: -20,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: _isPressed ? 0.12 : 0.04),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Center(
                            child: hasImage
                                ? Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      AspectRatio(
                                        aspectRatio: 1,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.08),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(14),
                                            child: Image.network(
                                              widget.imageUrl!,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (widget.isSuggested)
                                        Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.warning,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                                        ),
                                    ],
                                  )
                                : Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topRight,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          widget.emoji,
                                          style: TextStyle(
                                            fontSize: widget.compact ? 44 : 48,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black.withValues(alpha: 0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      if (widget.isSuggested)
                                        Positioned(
                                          right: -8,
                                          top: -8,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppTheme.warning,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.compact ? 13 : 15,
                            fontWeight: FontWeight.w800,
                            color: _isPressed ? accent : AppTheme.textDark,
                            letterSpacing: -0.2,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms).scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1.0, 1.0),
          duration: 350.ms,
          curve: Curves.easeOutBack,
        );
  }
}
