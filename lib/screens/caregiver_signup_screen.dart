import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../utils/app_exceptions.dart';
import '../theme/app_theme.dart';

/// Premium caregiver sign-up screen.
class CaregiverSignupScreen extends ConsumerStatefulWidget {
  const CaregiverSignupScreen({super.key});
  @override
  ConsumerState<CaregiverSignupScreen> createState() => _CaregiverSignupScreenState();
}

class _CaregiverSignupScreenState extends ConsumerState<CaregiverSignupScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  Future<void> _createFamilyOnly(String familyCode) async {
    final familyRepo = ref.read(familyRepositoryProvider);
    final family = await familyRepo.createFamily(familyCode);
    await ref.read(sessionProvider.notifier).setSession(
      role: UserRole.caregiver,
      familyCode: family.familyCode,
      familyId: family.id,
    );
  }



  String _friendlySignupError(Object e) {
    final msg = e.toString().toLowerCase();
    if (e is AuthException) {
      final message = e.message.toLowerCase();
      if (message.contains('already registered') || message.contains('already been registered')) {
        return 'This email is already registered. Try signing in instead.';
      }
      if (message.contains('valid email') || message.contains('invalid')) {
        return 'Please enter a valid email address.';
      }
      if (message.contains('password') && message.contains('short')) {
        return 'Password must be at least 6 characters.';
      }
      if (message.contains('network')) {
        return 'Network error. Check your connection and try again.';
      }
      return e.message;
    }
    if (msg.contains('duplicate') || msg.contains('unique') || msg.contains('already exists')) {
      return 'This family code is already in use. Tap 🔄 to generate a new one.';
    }
    return 'Sign-up failed: ${e.toString().split('\n').first}';
  }

  Future<void> _signUp() async {
    final familyCode = _codeCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text;

    if (familyCode.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    final authRepo = ref.read(authRepositoryProvider);
    if (!authRepo.isSignedIn && (email.isEmpty || password.isEmpty)) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    // Password strength validation
    if (!authRepo.isSignedIn && password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    if (familyCode.length < 4 || familyCode.length > 8) {
      setState(() => _error = 'Family code must be 4-8 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      if (!authRepo.isSignedIn) {
        await authRepo.signUpWithEmail(email, password);
      }

      await _createFamilyOnly(familyCode);
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = _friendlySignupError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    bool? obscureToggle,
    VoidCallback? onToggle,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    TextCapitalization capitalization = TextCapitalization.none,
    String? helperText,
    int delay = 0,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.inputRadius,
        boxShadow: AppTheme.softShadow,
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          suffixIcon: suffixIcon ?? (obscureToggle != null
              ? IconButton(
                  icon: Icon(
                    obscureToggle ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: AppTheme.textLight),
                  onPressed: onToggle,
                )
              : null),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideX(begin: -0.05);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF4F6FB), Color(0xFFE6F0FF)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
          Positioned(
            bottom: -50, right: -30,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.secondary.withValues(alpha: 0.1), Colors.transparent]),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.go('/caregiver-signin'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(14),
                        boxShadow: AppTheme.softShadow),
                      child: const Icon(Icons.arrow_back_rounded, size: 22),
                    ),
                  ),
                  const SizedBox(height: 30),

                  Text('Create Account 🚀',
                      style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900))
                      .animate().fadeIn(),
                  const SizedBox(height: 6),
                  Text('Set up your caregiver account and family',
                      style: GoogleFonts.poppins(color: AppTheme.textMedium, fontSize: 15))
                      .animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 32),

                  _inputField(
                    controller: _emailCtrl, label: 'Email',
                    icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress, delay: 300),
                  const SizedBox(height: 14),
                  _inputField(
                    controller: _passCtrl, label: 'Password',
                    icon: Icons.lock_rounded, obscure: _obscurePass,
                    obscureToggle: _obscurePass,
                    onToggle: () => setState(() => _obscurePass = !_obscurePass), delay: 400),
                  const SizedBox(height: 14),
                  _inputField(
                    controller: _codeCtrl, label: 'Family Code',
                    icon: Icons.family_restroom_rounded,
                    capitalization: TextCapitalization.characters,
                    helperText: 'Permanent lifetime code (4-8 chars). Share to connect child.',
                    delay: 500),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.2)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
                        ]),
                      ),
                    ),

                  const SizedBox(height: 28),

                  GestureDetector(
                    onTap: _loading ? null : _signUp,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: _loading ? AppTheme.darkGradient : AppTheme.primaryGradient,
                        borderRadius: AppTheme.inputRadius,
                        boxShadow: _loading ? [] : AppTheme.vibrantShadow,
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text('Create Account & Family',
                                style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/caregiver-signin'),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
                          children: const [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(text: 'Sign In',
                                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
