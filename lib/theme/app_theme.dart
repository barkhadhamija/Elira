import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colours.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: AppColours.surface,
        colorScheme: ColorScheme.light(
          primary: AppColours.accentTeal,
          error: AppColours.dangerRed,
          surface: AppColours.surface,
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.dmSerifDisplay(
            fontSize: 32,
            color: AppColours.textDark,
            fontWeight: FontWeight.w400,
          ),
          displayMedium: GoogleFonts.dmSerifDisplay(
            fontSize: 24,
            color: AppColours.textDark,
            fontWeight: FontWeight.w400,
          ),
          titleLarge: GoogleFonts.dmSans(
            fontSize: 18,
            color: AppColours.textDark,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: GoogleFonts.dmSans(
            fontSize: 16,
            color: AppColours.textDark,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: GoogleFonts.dmSans(
            fontSize: 16,
            color: AppColours.textDark,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: GoogleFonts.dmSans(
            fontSize: 14,
            color: AppColours.textDark,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: GoogleFonts.dmSans(
            fontSize: 12,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColours.accentTeal,
            foregroundColor: AppColours.textLight,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColours.textMuted.withOpacity(0.3)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: AppColours.textMuted.withOpacity(0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColours.accentTeal, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      );
}
