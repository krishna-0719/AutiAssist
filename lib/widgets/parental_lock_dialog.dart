import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Premium PIN dialog with glassmorphism, keypad, and database PIN verification.
class ParentalLockDialog extends ConsumerStatefulWidget {
  const ParentalLockDialog({super.key});

  /// Shows the dialog. Returns true if unlocked, false if cancelled.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const ParentalLockDialog(),
    );
    return result ?? false;
  }

  /// Hash a PIN using salted SHA-256.
  static String hashPin(String pin) {
    final salted = 'care_child_v2_${pin}_salt_2024';
    return crypto.sha256.convert(utf8.encode(salted)).toString();
  }

  @override
  ConsumerState<ParentalLockDialog> createState() => _ParentalLockDialogState();
}

class _ParentalLockDialogState extends ConsumerState<ParentalLockDialog>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _error = false;
  String? _storedPinHash;
  bool _loading = true;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Default PIN only used when no family PIN is set in the database
  static const _defaultPin = '1234';

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _loadFamilyPin();
  }

  /// Load the stored PIN hash from the Supabase families table.
  Future<void> _loadFamilyPin() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        final result = await Supabase.instance.client
            .from('families')
            .select('pin_hash')
            .eq('created_by', userId)
            .maybeSingle();

        if (result != null && result['pin_hash'] != null) {
          _storedPinHash = result['pin_hash'] as String;
        }
      }
    } catch (_) {
      // Gracefully fall back to default PIN
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_enteredPin.length >= 4) return;
    HapticFeedback.lightImpact();
    setState(() {
      _error = false;
      _enteredPin += digit;
    });

    if (_enteredPin.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), _verify);
    }
  }

  void _onDelete() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _error = false;
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
    });
  }

  void _verify() {
    final enteredHash = ParentalLockDialog.hashPin(_enteredPin);

    bool valid;
    if (_storedPinHash != null) {
      // Compare against database PIN hash
      valid = enteredHash == _storedPinHash;
    } else {
      // No PIN set in DB — allow default PIN
      valid = _enteredPin == _defaultPin;
    }

    if (valid) {
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      setState(() {
        _error = true;
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: AppTheme.cardRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: AppTheme.cardRadius,
              border: Border.all(color: AppTheme.glassBorder),
              boxShadow: AppTheme.vibrantShadow,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppTheme.coloredShadow(AppTheme.primary),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 18),

                  Text('Parental Lock',
                      style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    _storedPinHash != null
                        ? 'Enter your family PIN'
                        : 'Enter the 4-digit caregiver PIN',
                    style: const TextStyle(
                        color: AppTheme.textMedium, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    // PIN dots
                    AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (_, child) {
                        final shake = _shakeAnimation.value *
                            10 *
                            ((_shakeController.value * 4).truncate().isEven
                                ? 1
                                : -1);
                        return Transform.translate(
                            offset: Offset(shake, 0), child: child);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          final filled = i < _enteredPin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            width: filled ? 18 : 16,
                            height: filled ? 18 : 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _error
                                  ? AppTheme.danger
                                  : filled
                                      ? AppTheme.primary
                                      : AppTheme.cardBorder,
                              boxShadow: filled
                                  ? [
                                      BoxShadow(
                                          color: AppTheme.primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8)
                                    ]
                                  : [],
                            ),
                          );
                        }),
                      ),
                    ),

                    if (_error) ...[
                      const SizedBox(height: 12),
                      const Text('Incorrect PIN',
                          style: TextStyle(
                              color: AppTheme.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ],

                    const SizedBox(height: 28),

                    // Keypad
                    ...List.generate(3, (row) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (col) {
                            final digit = '${row * 3 + col + 1}';
                            return _KeypadButton(
                                digit: digit, onTap: () => _onDigit(digit));
                          }),
                        ),
                      );
                    }),

                    // Bottom row: Cancel, 0, Delete
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _KeypadButton(
                          icon: Icons.close_rounded,
                          onTap: () => Navigator.pop(context, false),
                        ),
                        _KeypadButton(digit: '0', onTap: () => _onDigit('0')),
                        _KeypadButton(
                          icon: Icons.backspace_rounded,
                          onTap: _onDelete,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KeypadButton extends StatefulWidget {
  final String? digit;
  final IconData? icon;
  final VoidCallback onTap;

  const _KeypadButton({this.digit, this.icon, required this.onTap});

  @override
  State<_KeypadButton> createState() => _KeypadButtonState();
}

class _KeypadButtonState extends State<_KeypadButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 68,
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: _pressed
              ? AppTheme.primary.withValues(alpha: 0.08)
              : AppTheme.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: _pressed
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : AppTheme.cardBorder.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: widget.digit != null
              ? Text(widget.digit!,
                  style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _pressed ? AppTheme.primary : AppTheme.textDark))
              : Icon(widget.icon,
                  size: 20,
                  color: _pressed ? AppTheme.primary : AppTheme.textMedium),
        ),
      ),
    );
  }
}
