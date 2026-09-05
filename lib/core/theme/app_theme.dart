import 'package:flutter/material.dart';

/// "Manuscript" palette (2026-09-04 redesign) — kept Duolingo's *mechanics*
/// (flat shapes, depth built from a solid "shadow" colour under each raised
/// element rather than a blurred BoxShadow — see `core/widgets/duo_button
/// .dart`) but replaced its actual colours, which read as a generic
/// language-app skin rather than something built for this content. The new
/// palette pulls from illuminated Qur'an manuscripts instead: a deep
/// jewel-tone emerald as primary (not a bright cartoon lime), warm antique
/// gold rather than "bee" yellow, and a cream paper background instead of
/// clinical white/grey. Every call site still just says
/// `AppColors.primary`/`.gold`/etc. — only the values under those names
/// changed, so this cascades everywhere without touching individual
/// screens.
abstract class AppColors {
  // Primary — deep emerald
  static const Color primary = Color(0xFF0E8F6E);
  static const Color primaryDark = Color(0xFF0A6E55); // the 3D "shadow" face
  static const Color primaryLight = Color(0xFFD7F0E6);
  static const Color primaryDeep = Color(0xFF07422F); // text on primaryLight

  // Secondary — muted teal-blue, used for info / secondary actions
  static const Color blue = Color(0xFF2C87B0);
  static const Color blueDark = Color(0xFF206A8A);
  static const Color blueLight = Color(0xFFDCEEF5);

  // Streaks / XP / mastery — antique gold leaf, not bee yellow
  static const Color gold = Color(0xFFC79A2E);
  static const Color goldDark = Color(0xFF9E7A20);
  static const Color goldLight = Color(0xFFF6EBCE);

  // Aliases so every screen that already says "secondary" (mastery/sealed
  // accents) keeps working unchanged — same gold, just named to match
  // the vocabulary already used across the app.
  static const Color secondary = gold;
  static const Color secondaryDark = goldDark;
  static const Color secondaryLight = goldLight;

  // Hearts / errors — a deeper, less neon red
  static const Color red = Color(0xFFD8483F);
  static const Color redDark = Color(0xFFB33A32);
  static const Color redLight = Color(0xFFF8E0DD);

  // Accent — muted plum, used sparingly for gems/achievements
  static const Color purple = Color(0xFF9C6FB6);
  static const Color purpleDark = Color(0xFF7B5490);
  static const Color purpleLight = Color(0xFFEEE2F3);

  static const Color success = primary;
  static const Color successWash = primaryLight;
  static const Color error = red;
  static const Color errorWash = redLight;
  static const Color warning = gold;

  // Streak fire keeps its own name since it's used as an icon tint, not a
  // semantic colour.
  static const Color streakFire = Color(0xFFD97B29);
  static const Color xpGolden = gold;

  static const Color white = Color(0xFFFFFFFF);

  // Neutrals — warmed slightly off pure grey to sit with the cream ground
  // rather than fight it.
  static const Color grey900 = Color(0xFF3A362F); // body text
  static const Color grey800 = Color(0xFF4A453C);
  static const Color grey700 = Color(0xFF5B554A);
  static const Color grey600 = Color(0xFF7A7266); // secondary text
  static const Color grey500 = Color(0xFFA79E8F); // disabled text
  static const Color grey400 = Color(0xFFCFC5B2);
  static const Color grey300 = Color(0xFFE6DFCF); // borders
  static const Color grey200 = Color(0xFFF0EBDD);
  static const Color grey100 = Color(0xFFFAF7EF); // app background (cream)

  static const Color lightBackground = grey100;
  static const Color lightSurface = Color(0xFFFFFDF7);
  static const Color lightBorder = grey300;

  static const Color darkBackground = Color(0xFF11201B);
  static const Color darkSurface = Color(0xFF1A2E27);
  static const Color darkBorder = Color(0xFF33493F);
}

abstract class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract class AppRadius {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double circular = 999;
}

/// The "3D press" depth used by DuoButton and DuoTile — how many pixels of
/// the darker shadow face show beneath the coloured top face at rest.
abstract class AppDepth {
  static const double button = 5;
  static const double tile = 3;
}

/// Kept for the handful of call sites (cards, dividers) that still want a
/// soft ambient shadow rather than the flat 3D depth effect — used far more
/// sparingly than in the previous design.
abstract class AppShadows {
  static List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> hero = <BoxShadow>[
    BoxShadow(
      color: AppColors.primary.withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> gold = <BoxShadow>[
    BoxShadow(
      color: AppColors.gold.withOpacity(0.35),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}

abstract class AppGradients {
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryDark],
  );

  static const LinearGradient gilt = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.gold, AppColors.goldDark],
  );
}

/// Amiri (bundled as a real asset — see pubspec.yaml) is a proper Quranic
/// Naskh typeface, used as the primary font for every ayah. The rest of
/// this stack is kept only as a fallback for any glyph Amiri doesn't cover
/// (rare combining marks) — it used to be the *whole* story, which was the
/// bug: none of these names are actually installed on a typical machine or
/// loaded as web fonts, so the browser silently fell through to
/// 'Segoe UI'/'Arial' (neither has full Quranic diacritic coverage) and
/// rendered tofu boxes for some glyph combinations — confirmed live on the
/// splash screen's wordmark, which is this style's simplest, most exposed
/// user of all. Bundling Amiri fixes it deterministically everywhere this
/// style is used, not just the splash.
abstract class ArabicType {
  static const List<String> stack = <String>[
    'Amiri',
    'Scheherazade New',
    'Noto Naskh Arabic',
    'Traditional Arabic',
    'Segoe UI',
    'Arial',
  ];

  static TextStyle ayah({double size = 28, Color? color}) => TextStyle(
        fontFamily: 'Amiri',
        fontFamilyFallback: stack,
        fontSize: size,
        height: 2.0,
        color: color,
      );

  static TextStyle tile({Color? color}) => TextStyle(
        fontFamily: 'Amiri',
        fontFamilyFallback: stack,
        fontSize: 21,
        height: 1.7,
        color: color,
      );
}

class AppTheme {
  static ThemeData light() => _base(
        brightness: Brightness.light,
        background: AppColors.grey100,
        surface: AppColors.lightSurface,
        border: AppColors.lightBorder,
        text: AppColors.grey900,
        subtle: AppColors.grey600,
        field: AppColors.grey100,
      );

  static ThemeData dark() => _base(
        brightness: Brightness.dark,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        border: AppColors.darkBorder,
        text: AppColors.white,
        subtle: AppColors.grey400,
        field: AppColors.darkSurface,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color border,
    required Color text,
    required Color subtle,
    required Color field,
  }) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      // Vazirmatn is a typeface purpose-built for Persian UI text (full
      // Persian + Latin + digit coverage) — bundled as a real asset (see
      // pubspec.yaml) rather than left to whatever the browser's generic
      // complex-script fallback happens to render, which is inconsistent
      // and untimed (see ArabicType's doc comment for the same problem on
      // the Qur'an side). Set both at the ThemeData level (covers any
      // widget that reads Theme.of(context).textTheme/primaryTextTheme
      // without a fully custom TextTheme) and per-style below (covers the
      // explicit TextTheme this app actually passes, which otherwise
      // shadows the ThemeData-level default).
      fontFamily: 'Vazirmatn',
      scaffoldBackgroundColor: background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      // `outline`/`onSurfaceVariant` are the canonical home for anything
      // that used to be a hardcoded `AppColors.grey300`/`grey400` — card
      // borders, dividers, muted/disabled icons. Those raw constants are
      // light-mode values with no dark counterpart, so every call site
      // that used them directly stayed pale-cream even in dark mode,
      // fighting the dark background instead of sitting in it. Read them
      // via `context.borderColor`/`context.mutedColor` (below) instead of
      // `AppColors.grey300`/`grey400` from now on.
      colorScheme: isDark
          ? ColorScheme.dark(
              primary: AppColors.primary,
              secondary: AppColors.blue,
              surface: AppColors.darkSurface,
              error: AppColors.error,
              outline: border,
              outlineVariant: AppColors.darkBorder,
              onSurfaceVariant: subtle,
            )
          : ColorScheme.light(
              primary: AppColors.primary,
              secondary: AppColors.blue,
              surface: AppColors.lightSurface,
              error: AppColors.error,
              outline: border,
              outlineVariant: AppColors.grey200,
              onSurfaceVariant: subtle,
            ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: text,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: text,
          letterSpacing: -0.2,
        ),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: text,
            letterSpacing: -0.6,
            height: 1.2),
        displayMedium: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: text,
            letterSpacing: -0.4,
            height: 1.25),
        headlineMedium: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: text,
            letterSpacing: -0.3),
        headlineSmall: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 19, fontWeight: FontWeight.w800, color: text),
        titleLarge: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 17, fontWeight: FontWeight.w800, color: text),
        titleMedium: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 15, fontWeight: FontWeight.w700, color: text),
        bodyLarge: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 16, height: 1.6, color: text, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14, height: 1.6, color: subtle, fontWeight: FontWeight.w500),
        bodySmall: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 12.5, height: 1.5, color: subtle, fontWeight: FontWeight.w600),
        labelLarge: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 14, fontWeight: FontWeight.w800, color: text),
        labelMedium: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 12.5, fontWeight: FontWeight.w700, color: subtle),
        labelSmall: TextStyle(
            fontFamily: 'Vazirmatn',
            fontSize: 11.5, fontWeight: FontWeight.w700, color: subtle),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: border, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.blue, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 2, space: 1),
    );
  }
}

/// Shorthand for the two theme-aware neutrals that replaced hardcoded
/// `AppColors.grey300`/`grey400` app-wide (see the dark-mode fix note on
/// `colorScheme` above): `borderColor` for card/tile borders and dividers,
/// `mutedColor` for secondary/disabled icons and de-emphasised glyphs.
/// Both correctly flip between the light and dark palettes; the raw
/// `AppColors.grey300`/`grey400` constants do not and should no longer be
/// used directly for anything that needs to work in both themes.
extension ThemeColors on BuildContext {
  Color get borderColor => Theme.of(this).colorScheme.outline;
  Color get mutedColor => Theme.of(this).colorScheme.onSurfaceVariant;
}
