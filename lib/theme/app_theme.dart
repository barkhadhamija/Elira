import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colours.dart';

class AppTheme {
  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: AppColours.surface,
        colorScheme: ColorScheme.light(
          primary: AppColours.brandBlue,
          error: AppColours.dangerRed,
          surface: AppColours.surface,
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.inter(
            fontSize: 32,
            color: AppColours.textDark,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          displayMedium: GoogleFonts.inter(
            fontSize: 26,
            color: AppColours.textDark,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            color: AppColours.textDark,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            color: AppColours.textDark,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            color: AppColours.textDark,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            color: AppColours.textDark,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            color: AppColours.textMuted,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColours.brandBlue,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColours.inputFill,
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
            borderSide: BorderSide(color: AppColours.brandBlue, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        cardTheme: CardThemeData(
          color: AppColours.cardSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColours.divider, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColours.surface,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: AppColours.divider,
          iconTheme: IconThemeData(
            color: AppColours.textDark,
            size: 22,
          ),
          titleTextStyle: GoogleFonts.inter(
            fontSize: 16,
            color: AppColours.textDark,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: AppColours.divider,
          thickness: 1,
          space: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFFBDBDBD);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColours.brandBlue;
            }
            return const Color(0xFFE0E0E0);
          }),
        ),
      );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        colorScheme: ColorScheme.dark(
          primary: AppColours.brandBlueMuted,
          secondary: AppColours.brandBlueMuted,
          error: AppColours.dangerRed,
          surface: const Color(0xFF161826),
        ),
        textTheme: TextTheme(
          displayLarge: GoogleFonts.inter(
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
          displayMedium: GoogleFonts.inter(
            fontSize: 26,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
          titleLarge: GoogleFonts.inter(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
          titleMedium: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodyMedium: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
          bodySmall: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFFB4B6C8),
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColours.brandBlueMuted,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
            shadowColor: Colors.transparent,
            textStyle: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1D2B),
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
            borderSide: BorderSide(color: AppColours.brandBlueMuted, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF161826),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2A2E41), width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF0F111A),
          elevation: 0,
          scrolledUnderElevation: 0.5,
          shadowColor: const Color(0xFF2A2E41),
          iconTheme: const IconThemeData(
            color: Colors.white,
            size: 22,
          ),
          titleTextStyle: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2E41),
          thickness: 1,
          space: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return const Color(0xFF7E849A);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColours.brandBlueMuted;
            }
            return const Color(0xFF3A3F55);
          }),
        ),
      );
}
