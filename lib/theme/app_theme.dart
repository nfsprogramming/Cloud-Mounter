import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF0F0F10);
  static const Color surface = Color(0xFF161618);
  static const Color card = Color(0xFF1C1C1E);
  static const Color cardHover = Color(0xFF252528);
  static const Color border = Color(0xFF2C2C2E);
  static const Color accent = Color(0xFF2563EB);
  static const Color accentLight = Color(0xFF3B82F6);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFECEDEE);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textTertiary = Color(0xFF48484A);

  static const Map<String, Color> providerColors = {
    'gdrive': Color(0xFF4285F4),
    'dropbox': Color(0xFF0061FF),
    'onedrive': Color(0xFF0078D4),
    'mega': Color(0xFFD40000),
  };

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: accent,
        secondary: accentLight,
        error: error,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 14),
        bodyMedium: GoogleFonts.inter(color: textPrimary, fontSize: 13),
        bodySmall: GoogleFonts.inter(color: textSecondary, fontSize: 12),
        titleLarge: GoogleFonts.inter(
            color: textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(
            color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(
            color: textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
        labelLarge: GoogleFonts.inter(
            color: textPrimary, fontSize: 13, fontWeight: FontWeight.w500),
        labelSmall: GoogleFonts.inter(color: textSecondary, fontSize: 11),
      ),
      dividerColor: border,
      cardColor: card,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
        hintStyle: GoogleFonts.inter(color: textTertiary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return border;
        }),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
      dialogTheme: const DialogThemeData(backgroundColor: card),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: cardHover,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: border),
        ),
        textStyle: GoogleFonts.inter(color: textPrimary, fontSize: 12),
      ),
    );
  }
}
