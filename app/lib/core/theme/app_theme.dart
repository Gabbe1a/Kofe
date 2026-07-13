import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Source 1's calm, compact product system, adapted for Cyrillic Manrope.
abstract final class AppTheme {
  static ThemeData light() => _build(KofePalette.light, Brightness.light);

  static ThemeData dark() => _build(KofePalette.dark, Brightness.dark);

  static ThemeData _build(KofePalette palette, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.action,
      brightness: brightness,
      primary: palette.action,
      onPrimary: palette.onAction,
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      surface: palette.surface,
      onSurface: palette.ink,
      error: AppColors.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: palette.canvas,
    );
    final text = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: palette.ink,
      displayColor: palette.ink,
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(
          fontSize: 34,
          height: 1.04,
          letterSpacing: -1.45,
          fontWeight: FontWeight.w800,
        ),
        headlineLarge: text.headlineLarge?.copyWith(
          fontSize: 28,
          height: 1.08,
          letterSpacing: -1.05,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 22,
          height: 1.14,
          letterSpacing: -0.7,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 20,
          height: 1.15,
          letterSpacing: -0.45,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          height: 1.22,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: text.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: text.bodyMedium?.copyWith(
          color: palette.inkMuted,
          fontSize: 14,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: palette.canvas,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.manrope(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.45,
          color: palette.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.action,
          foregroundColor: palette.onAction,
          disabledBackgroundColor: palette.surfaceMuted,
          disabledForegroundColor: palette.inkMuted,
          minimumSize: const Size.fromHeight(60),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.ink,
          minimumSize: const Size.fromHeight(56),
          side: BorderSide(color: palette.line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.ink,
          textStyle: GoogleFonts.manrope(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.accent, width: 1.5),
        ),
        hintStyle: GoogleFonts.manrope(
          color: palette.inkMuted,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        labelStyle: GoogleFonts.manrope(color: palette.inkMuted),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.surfaceMuted,
        selectedColor: palette.ink,
        labelStyle: GoogleFonts.manrope(
          fontWeight: FontWeight.w700,
          color: palette.ink,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      dividerColor: palette.line,
      dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: GoogleFonts.manrope(color: palette.canvas),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(palette.surface),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? palette.ink
              : palette.line,
        ),
      ),
      extensions: [palette],
    );
  }
}
