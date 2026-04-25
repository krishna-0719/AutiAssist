import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthException;

import '../providers/service_providers.dart';
import '../providers/session_provider.dart';
import '../utils/app_exceptions.dart';
import '../theme/app_theme.dart';

/// Premium child join screen — anonymous login + family code entry.
class ChildJoinScreen extends ConsumerStatefulWidget {
  const ChildJoinScreen({super.key});
  @override
  ConsumerState<ChildJoinScreen> createState() => _ChildJoinScreenState();
}

class _ChildJoinScreenState extends ConsumerState<ChildJoinScreen> {
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _join() async {
    if (_codeCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter the family code.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      if (!authRepo.isSignedIn) {
        await authRepo.signInAnonymously();
      }
      
      final code = _codeCtrl.text.trim().toUpperCase();

      // Join the family via RPC — returns the family_id UUID directly
      String familyId;
      try {
        final supa = Supabase.instance.client;
        final result = await supa.rpc('join_family_by_code', params: {'p_code': code});
        familyId = result as String;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('not found')) {
          setState(() { _error = 'Family code not found. Check with your caregiver.'; _loading = false; });
        } else {
          setState(() { _error = 'Could not join family. Check your connection.'; _loading = false; });
        }
        return;
      }

      await ref.read(sessionProvider.notifier).setSession(
        role: UserRole.child, familyCode: code, familyId: familyId);
      if (mounted) context.go('/child');
    } on AuthException catch (e) {
      setState(() {
        _error = e.message.contains('anonymous')
            ? 'Child sign-in is not enabled in this Supabase project yet. Ask your caregiver to enable Anonymous Auth.'
            : e.message;
      });
    } catch (e) {
      setState(() => _error = 'Could not join the family right now. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
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
                colors: [Color(0xFFF4F6FB), Color(0xFFE6FFFA)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
          ),
          // Blob
          Positioned(
            top: -50, left: -60,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.secondary.withValues(alpha: 0.12), Colors.transparent]),
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
                    onTap: () => context.go('/role-select'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(14),
                        boxShadow: AppTheme.softShadow),
                      child: const Icon(Icons.arrow_back_rounded, size: 22),
                    ),
                  ),
                  const SizedBox(height: 48),

                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.coolGradient,
                        boxShadow: AppTheme.coloredShadow(AppTheme.secondary),
                      ),
                      child: const Text('👶', style: TextStyle(fontSize: 56)),
                    ).animate().fadeIn(duration: 600.ms).scale(
                          begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 900.ms),
                  ),

                  const SizedBox(height: 28),
                  Center(
                    child: Text('Join Your Family',
                        style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900))
                        .animate().fadeIn(delay: 300.ms),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Ask your caregiver for the family code',
                        style: GoogleFonts.poppins(color: AppTheme.textMedium, fontSize: 15))
                        .animate().fadeIn(delay: 500.ms),
                  ),
                  const SizedBox(height: 40),

                  // Code input
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.inputRadius,
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: TextField(
                      controller: _codeCtrl,
                      textCapitalization: TextCapitalization.characters,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: 'ABC123',
                        hintStyle: TextStyle(color: AppTheme.textLight.withValues(alpha: 0.5)),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.key_rounded, color: AppTheme.secondary, size: 18),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onSubmitted: (_) => _join(),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1),

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
                    onTap: _loading ? null : _join,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        gradient: _loading ? AppTheme.darkGradient : AppTheme.coolGradient,
                        borderRadius: AppTheme.inputRadius,
                        boxShadow: _loading ? [] : AppTheme.coloredShadow(AppTheme.secondary),
                      ),
                      child: Center(
                        child: _loading
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                            : Text('Join Family',
                                style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
