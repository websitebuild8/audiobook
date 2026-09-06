import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF173B36);
  static const emerald = Color(0xFF0D6B5D);
  static const mint = Color(0xFFDDF2EA);
  static const canvas = Color(0xFFF6F7F3);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHigh = Color(0xFFEDF3EF);
  static const outline = Color(0xFFD5E0DB);
  static const gold = Color(0xFFD7A84D);

  static const darkCanvas = Color(0xFF070A09);
  static const darkSurface = Color(0xFF101513);
  static const darkSurfaceHigh = Color(0xFF171E1B);
  static const darkOutline = Color(0xFF28342F);
  static const darkMint = Color(0xFF163C32);
  static const darkGold = Color(0xFF79D8B7);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: brightness,
      primary: isDark ? const Color(0xFF52C6A4) : emerald,
      secondary: isDark ? darkGold : gold,
      surface: isDark ? darkCanvas : canvas,
      outline: isDark ? darkOutline : outline,
    ).copyWith(
      surfaceContainer: isDark ? darkSurface : surface,
      surfaceContainerHigh: isDark ? darkSurfaceHigh : surfaceHigh,
      primaryContainer: isDark ? darkMint : mint,
      onPrimaryContainer: isDark ? const Color(0xFFD9FFF1) : ink,
    );

    final primaryText = isDark ? Colors.white : ink;
    final secondaryText =
        isDark ? const Color(0xFF9EADA7) : const Color(0xFF49635F);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      fontFamily: 'Faseyha',
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: 36,
          height: 1.25,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
        headlineSmall: TextStyle(
          fontSize: 25,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          height: 1.45,
          fontWeight: FontWeight.w700,
          color: primaryText,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          height: 1.45,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        bodyLarge: TextStyle(fontSize: 17, height: 1.55, color: primaryText),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: secondaryText,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainer,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        hintStyle: TextStyle(color: secondaryText.withValues(alpha: .72)),
        prefixIconColor: secondaryText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      dividerColor: scheme.outline,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: primaryText),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
