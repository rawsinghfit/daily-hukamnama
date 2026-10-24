import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Warm "gutka page" palette: cream paper, dark ink, kesri and maroon.
class AppColors {
  static const paper = Color(0xFFFBF6EC);
  static const card = Color(0xFFFFFDF8);
  static const ink = Color(0xFF2B2118);
  static const muted = Color(0xFF7A6A58);
  static const kesri = Color(0xFFE07A1F);
  static const maroon = Color(0xFF7A1F2B);
  static const line = Color(0xFFE9DFCC);
}

TextStyle headingStyle(double size, {Color color = AppColors.ink}) =>
    GoogleFonts.lora(fontSize: size, fontWeight: FontWeight.w600, color: color);

TextStyle gurmukhiStyle(double size, {Color color = AppColors.ink}) =>
    GoogleFonts.notoSerifGurmukhi(fontSize: size, height: 1.7, color: color);

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.kesri,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.maroon,
    onPrimary: Colors.white,
    secondary: AppColors.kesri,
    surface: AppColors.paper,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.muted,
    surfaceContainerLow: AppColors.card,
    surfaceContainer: AppColors.card,
    surfaceContainerHigh: AppColors.card,
    outlineVariant: AppColors.line,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final textTheme = GoogleFonts.nunitoSansTextTheme(base.textTheme)
      .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.paper,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: headingStyle(20, color: AppColors.maroon),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.all(Radius.circular(18)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.line),
  );
}
