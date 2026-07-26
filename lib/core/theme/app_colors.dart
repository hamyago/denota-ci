// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Palette principale DeNoTa ──────────────────────
  static const Color primary       = Color(0xFF1B5E3B); // Vert Savane
  static const Color primaryLight  = Color(0xFF267F50); // Vert clair
  static const Color primaryDark   = Color(0xFF0D3D24); // Vert foncé
  static const Color primaryBg     = Color(0xFFE8F5EE); // Fond vert pâle

  static const Color accent        = Color(0xFFF5A623); // Or Soleil
  static const Color accentLight   = Color(0xFFFDF3DC); // Fond or pâle
  static const Color accentDark    = Color(0xFFC88214); // Or profond

  static const Color ink           = Color(0xFF0D1B2A); // Nuit Abidjan
  static const Color inkLight      = Color(0xFF1A2D40); // Nuit claire

  static const Color blue          = Color(0xFF1A73C8); // Bleu Lagune
  static const Color blueBg        = Color(0xFFE8F0FE);

  // ── Neutres ───────────────────────────────────────
  static const Color white         = Color(0xFFFFFFFF);
  static const Color background    = Color(0xFFF7F8FC);
  static const Color surface       = Color(0xFFFFFFFF);
  static const Color surfaceGrey   = Color(0xFFF0F2F5);

  static const Color grey100       = Color(0xFFF4F6F8);
  static const Color grey200       = Color(0xFFE8ECF0);
  static const Color grey300       = Color(0xFFD0D7DE);
  static const Color grey400       = Color(0xFFA8B2BC);
  static const Color grey500       = Color(0xFF6B7785);
  static const Color grey600       = Color(0xFF4A5568);
  static const Color grey700       = Color(0xFF2D3748);
  static const Color grey800       = Color(0xFF1A202C);

  // ── Sémantiques ───────────────────────────────────
  static const Color success       = Color(0xFF22C55E);
  static const Color successBg     = Color(0xFFDCFCE7);
  static const Color error         = Color(0xFFEF4444);
  static const Color errorBg       = Color(0xFFFEE2E2);
  static const Color warning       = Color(0xFFF59E0B);
  static const Color warningBg     = Color(0xFFFEF3C7);
  static const Color info          = Color(0xFF3B82F6);
  static const Color infoBg        = Color(0xFFEFF6FF);

  // ── Badges KYC ────────────────────────────────────
  static const Color kycBronze     = Color(0xFFCD7F32);
  static const Color kycSilver     = Color(0xFFC0C0C0);
  static const Color kycGold       = Color(0xFFFFD700);

  // ── Talent Score gradient ─────────────────────────
  static const List<Color> scoreGradient = [
    Color(0xFFEF4444), // 0-30 rouge
    Color(0xFFF59E0B), // 31-60 orange
    Color(0xFF22C55E), // 61-80 vert
    Color(0xFFF5A623), // 81-100 or
  ];
}
