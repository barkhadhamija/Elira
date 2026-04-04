import 'package:flutter/material.dart';

class AppColours {
  // ── Backgrounds ──────────────────────────────────────────────────────────────
  static const Color primaryBackground = Color(0xFFF5F4F0); // warm off-white (splash/login left)
  static const Color surface           = Color(0xFFFFFFFF); // pure white scaffold
  static const Color cardSurface       = Color(0xFFFFFFFF); // card white
  static const Color cardBackground    = Color(0xFFF7F7F7); // slightly grey card bg
  static const Color inputFill         = Color(0xFFF0F0F0); // input field background

  // ── Brand ────────────────────────────────────────────────────────────────────
  static const Color brandBlue         = Color(0xFF2B2DC8); // deep indigo / primary brand
  static const Color accentTeal        = Color(0xFF2B2DC8); // alias → brand blue
  static const Color accentLavenderSoft= Color(0xFFEEEEFD); // light blue tint bg
  static const Color brandBlueMuted    = Color(0xFF5558E3); // lighter variant

  // ── SOS ──────────────────────────────────────────────────────────────────────
  static const Color dangerRed         = Color(0xFFE53935); // bright red SOS

  // ── Text ─────────────────────────────────────────────────────────────────────
  static const Color textDark          = Color(0xFF1A1A2E); // deep navy black
  static const Color textLight         = Color(0xFFFFFFFF);
  static const Color textMuted         = Color(0xFF888899); // soft grey
  static const Color textBlue          = Color(0xFF2B2DC8); // brand blue text

  // ── Status badges ────────────────────────────────────────────────────────────
  static const Color badgeUploading    = Color(0xFFF59E0B);
  static const Color badgeAnchored     = Color(0xFF2B2DC8);
  static const Color badgeCertified    = Color(0xFF22C55E); // bright green
  static const Color badgeGreen        = Color(0xFF22C55E);

  // ── Dividers / borders ───────────────────────────────────────────────────────
  static const Color divider           = Color(0xFFE8E8EE);
  static const Color borderLight       = Color(0xFFE0E0E8);
}
