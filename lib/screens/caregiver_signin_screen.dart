import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../utils/app_exceptions.dart';
import '../theme/app_theme.dart';

/// Premium caregiver sign-in screen.
class CaregiverSigninScreen extends ConsumerStatefulWidget {
  const CaregiverSigninScreen({super.key});
  @override
  ConsumerState<CaregiverSigninScreen> createState() => _CaregiverSigninScreenState();
}

class _CaregiverSigninScreenState extends ConsumerState<CaregiverSigninScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePass = true;
  String? _error;

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email first, then tap Forgot Password.');
      return;
    }

    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Check your inbox.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not send reset email. Please try again.');
    }
  }

  String _friendlyAuthError(Object e) {
    if (e is AuthException) {
      final message = e.message.toLowerCase();
      if (message.contains('invalid login credentials')) {
        return 'Email or password is incorrect.';
      }
      if (message.contains('email not confirmed')) {
        return 'Your email is not confirmed yet. Check your inbox.';
      }
      if (message.contains('network')) {
        return 'Network error. Check your connection and try again.';
      }
      return e.message;
    }
    return 'Sign in failed. Please try again.';
  }

  Future<void> _signIn() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithPassword(_emailCtrl.text.trim(), _passCtrl.text);

      final familyRepo = ref.read(familyRepositoryProvider);
      final family = await familyRepo.findMyFamily();

      if (family != null) {
        await ref.read(sessionProvider.notifier).setSession(
          role: UserRole.caregiver,
          familyCode: family.familyCode,
          familyId: family.id,
        );
        if (mounted) context.go('/dashboard');
      } else {
        if (mounted) context.go('/caregiver-signup');
      }
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF4F6FB), Color(0xFFF0E6FF)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Decorative blob
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.primary.withValues(alpha: 0.1), Colors.transparent],
                ),
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
                  // Back button
                  GestureDetector(
                    onTap: () => context.go('/role-select'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, size: 22),
                    ),
                  ),
                  const SizedBox(height: 36),

                  Text('Welcome Back 👋',
                      style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900))
                      .animate().fadeIn(),
                  const SizedBox(height: 6),
                  Text('Sign in to your caregiver account',
                      style: GoogleFonts.poppins(color: AppTheme.textMedium, fontSize: 15))
                      .animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: 40),

                  // Email field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.inputRadius,
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.email_rounded, color: AppTheme.primary, size: 18),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.05),

                  const SizedBox(height: 16),

                  // Password field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.inputRadius,
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.lock_rounded, color: AppTheme.primary, size: 18),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: AppTheme.textLight,
                          ),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _signIn(),
                    ),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.05),

                  const SizedBox(height: 8),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _loading ? null : _resetPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ),

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
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(color: AppTheme.danger, fontSize: 13))),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 28),

                  // Gradient sign in button
                  GestureDetector(
                    onTap: _loading ? null : _signIn,
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
                            : Text('Sign In',
                                style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 20),

                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/caregiver-signup'),
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.poppins(fontSize: 14, color: AppTheme.textMedium),
                          children: const [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: 'Sign Up',
                              style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
