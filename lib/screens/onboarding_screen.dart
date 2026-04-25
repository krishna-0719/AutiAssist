import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Premium onboarding with glassmorphic cards and smooth transitions.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  final _pages = [
    {
      'emoji': '💬',
      'title': 'Communicate Easily',
      'desc': 'Your child can express needs by tapping simple, colorful symbols — no words needed.',
      'gradient': AppTheme.purpleGradient,
    },
    {
      'emoji': '📍',
      'title': 'Know Their Location',
      'desc': 'WiFi-based room detection tells you exactly where your child is — no GPS needed.',
      'gradient': AppTheme.coolGradient,
    },
    {
      'emoji': '🧠',
      'title': 'AI That Learns',
      'desc': 'The app learns your child\'s unique patterns and proactively suggests what they need.',
      'gradient': AppTheme.warmGradient,
    },
  ];

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (mounted) context.go('/role-select');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Soft background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF4F6FB), Color(0xFFE8EDF2)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GestureDetector(
                      onTap: _complete,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: AppTheme.pillRadius,
                          boxShadow: AppTheme.softShadow,
                        ),
                        child: const Text('Skip',
                            style: TextStyle(color: AppTheme.textMedium, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                ),

                // Pages
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _buildPage(_pages[i]),
                  ),
                ),

                // Bottom bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Animated dots
                      Row(
                        children: List.generate(_pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == i ? 36 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == i ? AppTheme.primary : AppTheme.textLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: _currentPage == i
                                  ? [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.3), blurRadius: 8)]
                                  : [],
                            ),
                          );
                        }),
                      ),

                      // Next / Get Started button
                      GestureDetector(
                        onTap: _currentPage == _pages.length - 1
                            ? _complete
                            : () => _controller.nextPage(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: AppTheme.inputRadius,
                            boxShadow: AppTheme.vibrantShadow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                                style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(Map<String, dynamic> page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Emoji in gradient circle
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: page['gradient'] as LinearGradient,
              boxShadow: [
                BoxShadow(
                  color: (page['gradient'] as LinearGradient).colors.first.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Text(page['emoji'] as String, style: const TextStyle(fontSize: 56)),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.5, 0.5), curve: Curves.elasticOut, duration: 800.ms),

          const SizedBox(height: 40),

          Text(
            page['title'] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.5),
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: 16),

          Text(
            page['desc'] as String,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 15,
              color: AppTheme.textMedium,
              height: 1.6,
            ),
          ).animate().fadeIn(delay: 450.ms),
        ],
      ),
    );
  }
}
