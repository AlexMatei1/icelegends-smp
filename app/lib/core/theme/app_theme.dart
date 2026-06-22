import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Web void/deep palette
  static const background  = Color(0xFF020810);
  static const deep        = Color(0xFF040C1A);
  static const dark        = Color(0xFF071428);
  static const mid         = Color(0xFF0C1E3A);
  static const surface     = Color(0xFF040C1A);
  static const surfaceAlt  = Color(0xFF071428);
  static const border      = Color(0xFF0F2A4A);

  // Ice/cyan accent
  static const ice         = Color(0xFF64DFDF);
  static const iceBlue     = Color(0xFF4FC3F7);
  static const icePale     = Color(0xFFB2FEFA);

  // Other accents
  static const gold        = Color(0xFFFFD580);
  static const green       = Color(0xFF64FFDA);
  static const red         = Color(0xFFFF5252);
  static const purple      = Color(0xFFCE93D8);

  // Text
  static const textPrimary = Color(0xFFE0F7FA);
  static const textMuted   = Color(0xFF7BAFD4);
  static const textDim     = Color(0xFF3D6E8A);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary:   AppColors.ice,
      secondary: AppColors.gold,
      surface:   AppColors.surface,
      error:     AppColors.red,
      outline:   AppColors.border,
      onSurface: AppColors.textPrimary,
      onPrimary: AppColors.background,
    ),
    textTheme: TextTheme(
      displayLarge:   GoogleFonts.exo2(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      displayMedium:  GoogleFonts.exo2(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineMedium: GoogleFonts.exo2(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      headlineSmall:  GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleLarge:     GoogleFonts.exo2(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      titleMedium:    GoogleFonts.exo2(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall:     GoogleFonts.exo2(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge:      GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      bodyMedium:     GoogleFonts.inter(fontSize: 14, color: AppColors.textMuted),
      bodySmall:      GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
      labelLarge:     GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      labelMedium:    GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      labelSmall:     GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.deep,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.exo2(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.dark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.ice, width: 1.5),
      ),
      labelStyle: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 13),
      hintStyle:  GoogleFonts.inter(color: AppColors.textDim, fontSize: 13),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.ice,
        foregroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: GoogleFonts.exo2(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
        elevation: 0,
      ),
    ),
    dividerColor: AppColors.border,
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ice,
      linearTrackColor: AppColors.border,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.mid,
      contentTextStyle: GoogleFonts.inter(color: AppColors.textPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
