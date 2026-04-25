import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App-wide premium theme — Material 3 with glassmorphism, autism-friendly colors.
class AppTheme {
  AppTheme._();

  // ─── Layout & Accessibility Tokens ──────────────────────
  static const double minTouchTarget = 60;
  static const double minSymbolCardSize = 100;
  static const double baseSpacing = 8;
  static const double screenPaddingMobile = 16;
  static const double screenPaddingTablet = 24;
  static const double cardPadding = 16;
  static const double sectionSpacing = 24;
  static const Duration gentleAnimation = Duration(milliseconds: 300);

  static const double mobileBreakpoint = 360;
  static const double tabletBreakpoint = 720;
  static const double desktopBreakpoint = 1024;

  // ─── Brand Colors ────────────────────────────────────────
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF9B8FFF);
  static const Color primaryDark = Color(0xFF4A3FCB);
  static const Color secondary = Color(0xFF00CEC9);
  static const Color secondaryDark = Color(0xFF009E99);
  static const Color accent = Color(0xFF0984E3);
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color danger = Color(0xFFD63031);
  static const Color orange = Color(0xFFE17055);
  static const Color pink = Color(0xFFFD79A8);

  // ─── Child UI Palette (soft pastel) ─────────────────────
  static const Color childBlue = Color(0xFFA8D8EA);
  static const Color childPink = Color(0xFFFFB6C1);
  static const Color childYellow = Color(0xFFFFF9A6);
  static const Color childGreen = Color(0xFFC5E8B7);
  static const Color childRequestButton = Color(0xFF4CAF50);

  // ─── Caregiver UI Palette ───────────────────────────────
  static const Color caregiverPrimary = Color(0xFF3F51B5);
  static const Color caregiverAccent = Color(0xFFFF5722);
  static const Color caregiverWarning = Color(0xFFFFC107);
  static const Color caregiverPing = Color(0xFF2196F3);

  // ─── Neutral Colors ──────────────────────────────────────
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF636E72);
  static const Color textLight = Color(0xFFB2BEC3);
  static const Color background = Color(0xFFF4F6FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8ECF0);
  static const Color shimmerBase = Color(0xFFE8EDF2);
  static const Color shimmerHighlight = Color(0xFFF5F7FA);
  static const Color accessibleTextOnLight = Color(0xFF111827);
  static const Color accessibleTextOnDark = Color(0xFFF9FAFB);

  // ─── Semantic Status Colors ─────────────────────────────
  static const Color statusPending = caregiverWarning;
  static const Color statusDone = success;
  static const Color statusError = Color(0xFFF44336);

  // ─── Glassmorphism Colors ────────────────────────────────
  static const Color glassWhite = Color(0x40FFFFFF);
  static const Color glassWhiteStrong = Color(0x80FFFFFF);
  static const Color glassBorder = Color(0x30FFFFFF);
  static const Color glassDark = Color(0x15000000);

  // ─── Shadows ─────────────────────────────────────────────
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.06),
          blurRadius: 20,
          offset: const Offset(0, 8),
          spreadRadius: 0,
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get vibrantShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.30),
          blurRadius: 24,
          offset: const Offset(0, 10),
          spreadRadius: -4,
        ),
      ];

  static List<BoxShadow> get glowShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.15),
          blurRadius: 40,
          spreadRadius: 4,
        ),
      ];

  static List<BoxShadow> coloredShadow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 16,
          offset: const Offset(0, 6),
          spreadRadius: -2,
        ),
      ];

  // ─── Gradients ───────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient purpleGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF9B8FFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warmGradient = LinearGradient(
    colors: [Color(0xFFFD79A8), Color(0xFFFDCB6E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient coolGradient = LinearGradient(
    colors: [Color(0xFF0984E3), Color(0xFF00CEC9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF2D3436), Color(0xFF636E72)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [Color(0xFFE8EDF2), Color(0xFFF5F7FA), Color(0xFFE8EDF2)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  // ─── Border Radius ───────────────────────────────────────
  static final BorderRadius cardRadius = BorderRadius.circular(24);
  static final BorderRadius inputRadius = BorderRadius.circular(16);
  static final BorderRadius chipRadius = BorderRadius.circular(14);
  static final BorderRadius pillRadius = BorderRadius.circular(50);
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(32),
  );

  // ─── Glassmorphic Decoration Helpers ─────────────────────

  /// Frosted glass card (white tint, blur, subtle border).
  static BoxDecoration get glassCard => BoxDecoration(
        color: glassWhite,
        borderRadius: cardRadius,
        border: Border.all(color: glassBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// Strong glass (more opaque).
  static BoxDecoration get glassCardStrong => BoxDecoration(
        color: glassWhiteStrong,
        borderRadius: cardRadius,
        border: Border.all(color: glassBorder, width: 1.5),
        boxShadow: softShadow,
      );

  /// Colored glass card.
  static BoxDecoration glassCardColored(Color tint) => BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: cardRadius,
        border: Border.all(color: tint.withValues(alpha: 0.25), width: 1.5),
        boxShadow: coloredShadow(tint),
      );

  /// Premium elevated card (solid, with vibrant shadow).
  static BoxDecoration get premiumCard => BoxDecoration(
        color: surface,
        borderRadius: cardRadius,
        boxShadow: softShadow,
        border: Border.all(color: cardBorder.withValues(alpha: 0.5), width: 1),
      );

  /// Glassmorphic wrapper widget (with backdrop blur).
  static Widget glassContainer({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(20),
    double blur = 12,
    Color? color,
    BorderRadius? radius,
  }) {
    return ClipRRect(
      borderRadius: radius ?? cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? glassWhite,
            borderRadius: radius ?? cardRadius,
            border: Border.all(color: glassBorder, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }

  // ─── ThemeData ───────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: danger,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          fontSize: 34,
          fontWeight: FontWeight.w900,
          color: textDark,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        headlineLarge: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
        bodyLarge: GoogleFonts.poppins(fontSize: 16, color: textDark),
        bodyMedium: GoogleFonts.poppins(fontSize: 14, color: textMedium),
        labelLarge: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: inputRadius),
          elevation: 0,
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: cardBorder.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: GoogleFonts.poppins(color: textLight, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: cardRadius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: chipRadius),
        elevation: 8,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: textDark,
        ),
        iconTheme: const IconThemeData(color: textDark),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
