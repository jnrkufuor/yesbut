import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/analysis.dart';

/// Brand palette: white canvas, three loud colors, one ink.
class GColors {
  static const red = Color(0xFFFF2E57);
  static const redSoft = Color(0xFFFFEAEE);
  static const blue = Color(0xFF2B5BFF);
  static const blueSoft = Color(0xFFE9EEFF);
  static const green = Color(0xFF00C46A);
  static const greenSoft = Color(0xFFE2F8EC);

  static const ink = Color(0xFF0E1020);
  static const inkSoft = Color(0xFF5D6178);
  static const inkFaint = Color(0xFF767A90);

  // Darker shades for small text on white/soft backgrounds (WCAG AA).
  static const redText = Color(0xFFE0173F);
  static const greenText = Color(0xFF008A4A);

  /// Readable foreground for content placed ON a brand color.
  static Color onColor(Color c) => c == green ? ink : white;
  static const line = Color(0xFFECEEF4);
  static const surface = Color(0xFFF5F6FA);
  static const white = Color(0xFFFFFFFF);

  static Color forSeverity(Severity s) => switch (s) {
        Severity.redFlag => red,
        Severity.headsUp => blue,
        Severity.goodNews => green,
      };

  static Color softForSeverity(Severity s) => switch (s) {
        Severity.redFlag => redSoft,
        Severity.headsUp => blueSoft,
        Severity.goodNews => greenSoft,
      };

  static Color textForSeverity(Severity s) => switch (s) {
        Severity.redFlag => redText,
        Severity.headsUp => blue,
        Severity.goodNews => greenText,
      };

  static Color textForScore(int score) =>
      score >= 70 ? greenText : (score >= 45 ? blue : redText);

  static Color forScore(int score) =>
      score >= 70 ? green : (score >= 45 ? blue : red);

  static Color softForScore(int score) =>
      score >= 70 ? greenSoft : (score >= 45 ? blueSoft : redSoft);

  static Color named(String name) => switch (name) {
        'red' => red,
        'green' => green,
        _ => blue,
      };

  static Color softNamed(String name) => switch (name) {
        'red' => redSoft,
        'green' => greenSoft,
        _ => blueSoft,
      };
}

class GRadius {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 26.0;
  static const xl = 34.0;
}

IconData severityIcon(Severity s) => switch (s) {
      Severity.redFlag => Icons.flag_rounded,
      Severity.headsUp => Icons.lightbulb_rounded,
      Severity.goodNews => Icons.thumb_up_alt_rounded,
    };

class AppTheme {
  static const font = 'GoogleSansFlex';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: GColors.blue,
      brightness: Brightness.light,
    ).copyWith(
      primary: GColors.blue,
      onPrimary: GColors.white,
      secondary: GColors.green,
      error: GColors.red,
      surface: GColors.white,
      onSurface: GColors.ink,
    );

    const t = TextTheme(
      displayLarge: TextStyle(fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.0),
      displayMedium: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.02),
      headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.0, height: 1.08),
      headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.7, height: 1.12),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w400, height: 1.45),
      bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.35),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: font,
      colorScheme: scheme,
      scaffoldBackgroundColor: GColors.white,
      textTheme: t.apply(bodyColor: GColors.ink, displayColor: GColors.ink, fontFamily: font),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: GColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: GColors.ink,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: GColors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          fontFamily: font, fontSize: 18, fontWeight: FontWeight.w800,
          color: GColors.ink, letterSpacing: -0.3,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: GColors.ink,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? GColors.white : GColors.inkSoft,
            )),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: font,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: s.contains(WidgetState.selected) ? GColors.ink : GColors.inkSoft,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GColors.surface,
        hintStyle: const TextStyle(color: GColors.inkFaint, fontWeight: FontWeight.w500),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GRadius.md),
          borderSide: const BorderSide(color: GColors.blue, width: 2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GColors.ink,
        contentTextStyle: const TextStyle(fontFamily: font, color: GColors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GRadius.md)),
      ),
      dividerColor: GColors.line,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      }),
    );
  }
}
