import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/analysis.dart';

/// V2 palette: white canvas, cherry / sunflower / electric blue, charcoal ink.
/// Scores and severities: cherry = bad, sunflower = careful, blue = fair.
class GColors {
  static const red = Color(0xFFF51D3A); // cherry
  static const redSoft = Color(0xFFFFE3E7);
  static const redDeep = Color(0xFFC8102B);
  static const blue = Color(0xFF4200FF); // electric blue
  static const blueSoft = Color(0xFFECE6FF);
  static const blueDeep = Color(0xFF3200C4);
  static const blueOnDark = Color(0xFF8C73FF);
  // "green" is kept as the name for the third brand color, now sunflower.
  static const green = Color(0xFFFFD100); // sunflower
  static const greenSoft = Color(0xFFFFF4C2);
  static const greenDeep = Color(0xFFEBBD02);
  static const sunflower = green;

  static const ink = Color(0xFF232120); // charcoal
  static const inkLift = Color(0xFF302D2B);
  static const inkSoft = Color(0xFF5E5852);
  static const inkFaint = Color(0xFF857E78);

  // Darker shades for small text on white/soft backgrounds.
  static const redText = Color(0xFFC8102B);
  static const greenText = Color(0xFF7A6000);

  /// Readable foreground for content placed ON a brand color.
  static Color onColor(Color c) => (c == green || c == white) ? ink : white;
  static const line = Color(0xFFE7E4E1);
  static const surface = Color(0xFFF3F2F1);
  static const white = Color(0xFFFFFFFF);

  static Color forSeverity(Severity s) => switch (s) {
        Severity.redFlag => red,
        Severity.headsUp => green,
        Severity.goodNews => blue,
      };

  static Color softForSeverity(Severity s) => switch (s) {
        Severity.redFlag => redSoft,
        Severity.headsUp => greenSoft,
        Severity.goodNews => blueSoft,
      };

  static Color textForSeverity(Severity s) => switch (s) {
        Severity.redFlag => redText,
        Severity.headsUp => greenText,
        Severity.goodNews => blue,
      };

  /// Deeper tone of a brand color, for line accents drawn on top of it.
  static Color deep(Color c) {
    if (c == red) return redDeep;
    if (c == blue) return blueDeep;
    if (c == green) return greenDeep;
    return inkLift;
  }

  static Color textForScore(int score) =>
      score >= 70 ? blue : (score >= 45 ? greenText : redText);

  static Color forScore(int score) =>
      score >= 70 ? blue : (score >= 45 ? green : red);

  static Color softForScore(int score) =>
      score >= 70 ? blueSoft : (score >= 45 ? greenSoft : redSoft);

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

  /// Parses "#RRGGBB" (or "RRGGBB"); null if it isn't a usable color.
  static Color? parseHex(String? hex) {
    if (hex == null) return null;
    var h = hex.trim().replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }
}

class GRadius {
  static const sm = 14.0;
  static const md = 22.0;
  static const lg = 30.0;
  static const xl = 40.0;
}

IconData severityIcon(Severity s) => switch (s) {
      Severity.redFlag => Icons.flag_rounded,
      Severity.headsUp => Icons.lightbulb_rounded,
      Severity.goodNews => Icons.thumb_up_alt_rounded,
    };

class AppTheme {
  static const font = 'GoogleSansFlex';
  static const display = 'Bricolage';
  static const serif = 'Newsreader';

  /// The italic serif used for "but" moments inside headings.
  static TextStyle serifOf(TextStyle? base) => (base ?? const TextStyle()).copyWith(
        fontFamily: serif,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w400,
        fontSize: (base?.fontSize ?? 16) * 1.1,
        letterSpacing: -((base?.fontSize ?? 16) * 0.02),
        height: base?.height,
      );

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

    const d = AppTheme.display;
    const t = TextTheme(
      displayLarge: TextStyle(fontFamily: d, fontSize: 52, fontWeight: FontWeight.w700, letterSpacing: -2, height: 1.0),
      displayMedium: TextStyle(fontFamily: d, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.5, height: 1.02),
      headlineLarge: TextStyle(fontFamily: d, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.3, height: 1.04),
      headlineMedium: TextStyle(fontFamily: d, fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.1),
      titleLarge: TextStyle(fontFamily: d, fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.6),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.45),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
      bodySmall: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.35),
      labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1),
      labelMedium: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      labelSmall: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: font,
      colorScheme: scheme,
      scaffoldBackgroundColor: GColors.white,
      textTheme: t.apply(bodyColor: GColors.ink, displayColor: GColors.ink),
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
          fontFamily: display, fontSize: 19, fontWeight: FontWeight.w700,
          color: GColors.ink, letterSpacing: -0.4,
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
        fillColor: GColors.white,
        hintStyle: const TextStyle(color: GColors.inkFaint, fontWeight: FontWeight.w400),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GRadius.md),
          borderSide: const BorderSide(color: GColors.line, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GRadius.md),
          borderSide: const BorderSide(color: GColors.line, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(GRadius.md),
          borderSide: const BorderSide(color: GColors.ink, width: 1),
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
