import 'dart:ui';

import 'package:flutter/material.dart';

import 'nebula_colors.dart';

class CosmoThemeTokens extends ThemeExtension<CosmoThemeTokens> {
  final Color background;
  final Color backgroundMid;
  final Color backgroundNear;
  final Color surface;
  final Color denseSurface;
  final Color surfaceBorder;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final Color primaryAccent;
  final Color secondaryAccent;
  final Color focusAccent;
  final Color success;
  final Color warning;
  final Color error;
  final double glowIntensity;

  const CosmoThemeTokens({
    required this.background,
    required this.backgroundMid,
    required this.backgroundNear,
    required this.surface,
    required this.denseSurface,
    required this.surfaceBorder,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.focusAccent,
    required this.success,
    required this.warning,
    required this.error,
    required this.glowIntensity,
  });

  static const darkInternals = CosmoThemeTokens(
    background: NebulaColors.deepVoid,
    backgroundMid: NebulaColors.spaceBlack,
    backgroundNear: NebulaColors.depthNear,
    surface: NebulaColors.nebulaSurface,
    denseSurface: NebulaColors.denseNebulaSurface,
    surfaceBorder: NebulaColors.surfaceBorder,
    primaryText: NebulaColors.softWhite,
    secondaryText: NebulaColors.mistWhite,
    mutedText: NebulaColors.dimText,
    primaryAccent: NebulaColors.stellarBlue,
    secondaryAccent: NebulaColors.nebulaPurple,
    focusAccent: NebulaColors.auroraCyan,
    success: NebulaColors.successMint,
    warning: NebulaColors.warningAmber,
    error: NebulaColors.errorRose,
    glowIntensity: 1.0,
  );

  // Light theme — cool blue-gray page, near-solid white panels.
  // Colored elements use paint-bleed spread shadows (glowIntensity: 0.0).
  // Text is near-black for maximum WCAG contrast.
  static const lightLite = CosmoThemeTokens(
    background: Color(0xFFE5EAF3),       // deeper cool blue-gray — good contrast with white panels
    backgroundMid: Color(0xFFD8DFEb),
    backgroundNear: Color(0xFFCDD5E2),
    surface: Color(0xFFF5F8FF),          // cool white — clearly distinct from background
    denseSurface: Color(0xFFFFFFFF),     // pure white for modals/forms
    surfaceBorder: Color(0x40000000),    // 25% black — clearly visible hairlines
    primaryText: Color(0xFF0D1117),      // near-black — maximum contrast
    secondaryText: Color(0xCC0D1117),    // 80%
    mutedText: Color(0xFF4B5563),        // gray-600 — readable secondary
    primaryAccent: Color(0xFF2563EB),    // royal blue — vivid but not neon
    secondaryAccent: Color(0xFF7C3AED), // deep violet
    focusAccent: Color(0xFF1D4ED8),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    glowIntensity: 0.0,                  // no glow — use spreading paint shadows only
  );

  @override
  CosmoThemeTokens copyWith({
    Color? background,
    Color? backgroundMid,
    Color? backgroundNear,
    Color? surface,
    Color? denseSurface,
    Color? surfaceBorder,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedText,
    Color? primaryAccent,
    Color? secondaryAccent,
    Color? focusAccent,
    Color? success,
    Color? warning,
    Color? error,
    double? glowIntensity,
  }) {
    return CosmoThemeTokens(
      background: background ?? this.background,
      backgroundMid: backgroundMid ?? this.backgroundMid,
      backgroundNear: backgroundNear ?? this.backgroundNear,
      surface: surface ?? this.surface,
      denseSurface: denseSurface ?? this.denseSurface,
      surfaceBorder: surfaceBorder ?? this.surfaceBorder,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedText: mutedText ?? this.mutedText,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      focusAccent: focusAccent ?? this.focusAccent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      glowIntensity: glowIntensity ?? this.glowIntensity,
    );
  }

  @override
  CosmoThemeTokens lerp(ThemeExtension<CosmoThemeTokens>? other, double t) {
    if (other is! CosmoThemeTokens) return this;
    return CosmoThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      backgroundMid: Color.lerp(backgroundMid, other.backgroundMid, t)!,
      backgroundNear: Color.lerp(backgroundNear, other.backgroundNear, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      denseSurface: Color.lerp(denseSurface, other.denseSurface, t)!,
      surfaceBorder: Color.lerp(surfaceBorder, other.surfaceBorder, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      focusAccent: Color.lerp(focusAccent, other.focusAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      glowIntensity: lerpDouble(glowIntensity, other.glowIntensity, t)!,
    );
  }
}
