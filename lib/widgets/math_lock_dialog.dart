import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Math Lock dialog with glassmorphism and keypad.
class MathLockDialog extends StatefulWidget {
  const MathLockDialog({super.key});

  /// Shows the dialog. Returns true if unlocked, false if cancelled.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => const MathLockDialog(),
    );
    return result ?? false;
  }

  @override
  State<MathLockDialog> createState() => _MathLockDialogState();
}

class _MathLockDialogState extends State<MathLockDialog>
    with SingleTickerProviderStateMixin {
  String _enteredAnswer = '';
  bool _error = false;
  late int _num1;
  late int _num2;
  late int _correctAnswer;
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn));
    _generateProblem();
  }

  void _generateProblem() {
    final rng = Random();
    _num1 = rng.nextInt(10) + 1; // 1 to 10
    _num2 = rng.nextInt(10) + 1; // 1 to 10
    _correctAnswer = _num1 + _num2;
    _enteredAnswer = '';
    _error = false;
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(String digit) {
    if (_enteredAnswer.length >= 3) return; // max 3 digits just in case
    HapticFeedback.lightImpact();
    setState(() {
      _error = false;
      _enteredAnswer += digit;
    });

    if (_enteredAnswer.length == _correctAnswer.toString().length) {
      Future.delayed(const Duration(milliseconds: 200), _verify);
    }
  }

  void _onDelete() {
    if (_enteredAnswer.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _error = false;
      _enteredAnswer = _enteredAnswer.substring(0, _enteredAnswer.length - 1);
    });
  }

  void _verify() {
    if (_enteredAnswer == _correctAnswer.toString()) {
      Navigator.pop(context, true);
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      setState(() {
        _error = true;
        _enteredAnswer = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
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
                  child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 18),

                Text('Parental Lock',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text(
                  'Solve this to access settings',
                  style: TextStyle(color: AppTheme.textMedium, fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Math Problem Display
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (_, child) {
                    final shake = _shakeAnimation.value *
                        10 *
                        ((_shakeController.value * 4).truncate().isEven ? 1 : -1);
                    return Transform.translate(offset: Offset(shake, 0), child: child);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: _error ? AppTheme.danger.withValues(alpha: 0.1) : AppTheme.cardBorder,
                      borderRadius: AppTheme.pillRadius,
                      border: Border.all(color: _error ? AppTheme.danger : Colors.transparent),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$_num1 + $_num2 = ',
                            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textDark)),
                        Text(_enteredAnswer.isEmpty ? '?' : _enteredAnswer,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: _error ? AppTheme.danger : AppTheme.primary,
                            )),
                      ],
                    ),
                  ),
                ),

                if (_error) ...[
                  const SizedBox(height: 12),
                  const Text('Incorrect answer',
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
                      color:
                          _pressed ? AppTheme.primary : AppTheme.textDark))
              : Icon(widget.icon,
                  size: 20,
                  color: _pressed ? AppTheme.primary : AppTheme.textMedium),
        ),
      ),
    );
  }
}
