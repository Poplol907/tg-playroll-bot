import 'package:flutter/material.dart';
import 'nebula_colors.dart';

abstract class NebulaTokens {
  // ── Radii ───────────────────────────────────────────────────────────────────
  static const double radiusXS = 8;
  static const double radiusSM = 12;
  static const double radiusMD = 18;
  static const double radiusLG = 24;
  static const double radiusXL = 32; // pill badges

  // ── Spacing (8px grid) ──────────────────────────────────────────────────────
  static const double sp2 = 2;
  static const double sp4 = 4;
  static const double sp8 = 8;
  static const double sp12 = 12;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp32 = 32;
  static const double sp48 = 48;

  // ── Motion durations ────────────────────────────────────────────────────────
  static const Duration tapFast = Duration(milliseconds: 120);
  static const Duration tapRelease = Duration(milliseconds: 200);
  static const Duration feedback = Duration(milliseconds: 220);
  static const Duration tabTransition = Duration(milliseconds: 360);
  static const Duration screenTransition = Duration(milliseconds: 520);
  static const Duration ambientLoop = Duration(milliseconds: 12000);

  // ── Blur levels ─────────────────────────────────────────────────────────────
  // Kept low intentionally — BackdropFilter cost grows as sigma², not linearly.
  // sigma=16 vs sigma=8 = 4x MORE work per pixel. Keep values small.
  static const double blurLight = 4;
  static const double blurMedium = 8;
  static const double blurDense = 12;

  // ── Glow presets — restrained 3-layer light model ───────────────────────────
  // Keep a white core, colored body, and wide haze, but cap blur/spread so dark
  // mode stays expressive without turning every state into a neon bloom.
  static List<BoxShadow> glowSoft(Color color) => [
        // Core highlight
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.34),
          blurRadius: 2,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        // Colored signal
        BoxShadow(
          color: color.withValues(alpha: 0.42),
          blurRadius: 8,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        // Ambient falloff
        BoxShadow(
          color: color.withValues(alpha: 0.10),
          blurRadius: 22,
          spreadRadius: 2,
          offset: Offset.zero,
        ),
      ];

  static List<BoxShadow> glowMedium(Color color) => [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.44),
          blurRadius: 3,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.52),
          blurRadius: 11,
          spreadRadius: 0,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.14),
          blurRadius: 31,
          spreadRadius: 5,
          offset: Offset.zero,
        ),
      ];

  static List<BoxShadow> glowFocus(Color color) => [
        BoxShadow(
          color: Colors.white.withValues(alpha: 0.54),
          blurRadius: 4,
          spreadRadius: 1,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.62),
          blurRadius: 14,
          spreadRadius: 2,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: 0.18),
          blurRadius: 40,
          spreadRadius: 8,
          offset: Offset.zero,
        ),
      ];

  // Semantic glow shortcuts
  static List<BoxShadow> glowSuccess() => glowMedium(NebulaColors.successMint);
  static List<BoxShadow> glowWarning() => glowMedium(NebulaColors.warningAmber);
  static List<BoxShadow> glowError() => glowMedium(NebulaColors.errorRose);
  static List<BoxShadow> glowPrimary() => glowSoft(NebulaColors.stellarBlue);

  // ── Luminous border-edge glow (border + matching outer shadow) ───────────────
  static BoxDecoration luminousBorder(Color accent,
          {double borderRadius = radiusMD}) =>
      BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      );

  // ── Z-order layers ───────────────────────────────────────────────────────────
  static const int zBackground = 0;
  static const int zContent = 10;
  static const int zOverlay = 20;
  static const int zModal = 30;
}
