import 'package:flutter/material.dart';
import 'nebula_alpha.dart';
import 'nebula_colors.dart';

abstract class NebulaTokens {
  // ── Alpha tokens ────────────────────────────────────────────────────────────
  // Re-exported here so callers that already import NebulaTokens don't need a
  // second import for opacity values. New code can use either path.
  static const double alphaWhisper = NebulaAlpha.whisper;
  static const double alphaMist = NebulaAlpha.mist;
  static const double alphaSurface = NebulaAlpha.surface;
  static const double alphaSubtle = NebulaAlpha.subtle;
  static const double alphaBorder = NebulaAlpha.border;
  static const double alphaAccent = NebulaAlpha.accent;
  static const double alphaMedium = NebulaAlpha.medium;
  static const double alphaStrong = NebulaAlpha.strong;
  static const double alphaHigh = NebulaAlpha.high;
  static const double alphaSolid = NebulaAlpha.solid;

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

  // Frosted surfaces multiply their base fill alpha by this factor so the
  // blurred backdrop is visible through the pane. SINGLE source of "how
  // see-through is frosted glass" across the whole app & all themes.
  // 1.0 = opaque (no glass), 0.0 = fully clear. 0.7 keeps text readable
  // while letting the blur read as real frosted glass.
  static const double frostedFillFactor = 0.7;

  // ── Input profile ──────────────────────────────────────────────────────────
  static const double inputBorderWidth = 1;
  static const double inputFocusAlphaLight = 0.34;
  static const double inputFocusAlphaDark = 0.55;
  static const double inputGlowAlphaLight = 0.04;
  static const double inputGlowAlphaDark = 0.16;
  static const double inputGlowBlurLight = 8;
  static const double inputGlowBlurDark = 14;
  static const double inputSpotlightAlphaLight = 0.18;

  // ── Glow presets — restrained 3-layer light model ───────────────────────────
  // Three intensities share the same structure: a small white core, a colored
  // signal body, and a wide low-alpha haze. Values come from NebulaAlpha so
  // global "сделать стекло плотнее/мягче" is a one-line change.
  static List<BoxShadow> glowSoft(Color color) => [
        BoxShadow(
          color: Colors.white.withValues(alpha: alphaAccent),
          blurRadius: 2,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: alphaMedium),
          blurRadius: 8,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: alphaMist),
          blurRadius: 22,
          spreadRadius: 2,
          offset: Offset.zero,
        ),
      ];

  static List<BoxShadow> glowMedium(Color color) => [
        BoxShadow(
          color: Colors.white.withValues(alpha: alphaMedium),
          blurRadius: 3,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: alphaStrong),
          blurRadius: 11,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: alphaSurface),
          blurRadius: 31,
          spreadRadius: 5,
          offset: Offset.zero,
        ),
      ];

  static List<BoxShadow> glowFocus(Color color) => [
        BoxShadow(
          color: Colors.white.withValues(alpha: alphaStrong),
          blurRadius: 4,
          spreadRadius: 1,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: alphaStrong),
          blurRadius: 14,
          spreadRadius: 2,
          offset: Offset.zero,
        ),
        BoxShadow(
          color: color.withValues(alpha: alphaSubtle),
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
        border:
            Border.all(color: accent.withValues(alpha: alphaMedium), width: 1),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: alphaBorder),
            blurRadius: 12,
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
