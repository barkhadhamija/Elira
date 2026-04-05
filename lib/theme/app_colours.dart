import 'package:flutter/material.dart';

import 'theme_mode_controller.dart';

class AppColours {
  static const Color _lightPrimaryBackground = Color(0xFFF5F4F0);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightCardSurface = Color(0xFFFFFFFF);
  static const Color _lightCardBackground = Color(0xFFF7F7F7);
  static const Color _lightInputFill = Color(0xFFF0F0F0);
  static const Color _lightBrandBlue = Color(0xFF2B2DC8);
  static const Color _lightBrandBlueMuted = Color(0xFF5558E3);
  static const Color _lightAccentLavenderSoft = Color(0xFFEEEEFD);
  static const Color _lightDangerRed = Color(0xFFE53935);
  static const Color _lightTextDark = Color(0xFF1A1A2E);
  static const Color _lightTextMuted = Color(0xFF888899);
  static const Color _lightTextBlue = Color(0xFF2B2DC8);
  static const Color _lightDivider = Color(0xFFE8E8EE);
  static const Color _lightBorder = Color(0xFFE0E0E8);

  static const Color _darkPrimaryBackground = Color(0xFF0D1018);
  static const Color _darkSurface = Color(0xFF111522);
  static const Color _darkCardSurface = Color(0xFF151A29);
  static const Color _darkCardBackground = Color(0xFF1A2030);
  static const Color _darkInputFill = Color(0xFF171D2B);
  static const Color _darkBrandBlue = Color(0xFF6B76FF);
  static const Color _darkBrandBlueMuted = Color(0xFF8892FF);
  static const Color _darkAccentLavenderSoft = Color(0xFF1B2232);
  static const Color _darkDangerRed = Color(0xFFFF6B66);
  static const Color _darkTextDark = Color(0xFFF4F7FF);
  static const Color _darkTextMuted = Color(0xFFB3B8CD);
  static const Color _darkTextBlue = Color(0xFF8C95FF);
  static const Color _darkDivider = Color(0xFF2A3145);
  static const Color _darkBorder = Color(0xFF30384D);

  static bool get _darkMode => AppThemeController.isDarkMode;

  // ── Backgrounds ──────────────────────────────────────────────────────────────
  static Color get primaryBackground =>
      _darkMode ? _darkPrimaryBackground : _lightPrimaryBackground;
  static Color get surface => _darkMode ? _darkSurface : _lightSurface;
  static Color get cardSurface => _darkMode ? _darkCardSurface : _lightCardSurface;
  static Color get cardBackground =>
      _darkMode ? _darkCardBackground : _lightCardBackground;
  static Color get inputFill => _darkMode ? _darkInputFill : _lightInputFill;

  // ── Brand ────────────────────────────────────────────────────────────────────
  static Color get brandBlue => _darkMode ? _darkBrandBlue : _lightBrandBlue;
  static Color get accentTeal => brandBlue;
  static Color get accentLavenderSoft =>
      _darkMode ? _darkAccentLavenderSoft : _lightAccentLavenderSoft;
  static Color get brandBlueMuted =>
      _darkMode ? _darkBrandBlueMuted : _lightBrandBlueMuted;

  // ── SOS ──────────────────────────────────────────────────────────────────────
  static Color get dangerRed => _darkMode ? _darkDangerRed : _lightDangerRed;

  // ── Text ─────────────────────────────────────────────────────────────────────
  static Color get textDark => _darkMode ? _darkTextDark : _lightTextDark;
  static Color get textLight => Colors.white;
  static Color get textMuted => _darkMode ? _darkTextMuted : _lightTextMuted;
  static Color get textBlue => _darkMode ? _darkTextBlue : _lightTextBlue;

  // ── Status badges ────────────────────────────────────────────────────────────
  static Color get badgeUploading => const Color(0xFFF59E0B);
  static Color get badgeAnchored => brandBlue;
  static Color get badgeCertified => const Color(0xFF22C55E);
  static Color get badgeGreen => const Color(0xFF22C55E);

  // ── Dividers / borders ───────────────────────────────────────────────────────
  static Color get divider => _darkMode ? _darkDivider : _lightDivider;
  static Color get borderLight => _darkMode ? _darkBorder : _lightBorder;
}
