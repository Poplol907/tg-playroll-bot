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

  // Warm off-white page with subtle warmth — soft shader lighting feel.
  // Slight glow allowed (0.3) for accent elements; text is near-charcoal.
  static const lightShader = CosmoThemeTokens(
    background: Color(0xFFFAFAF7),
    backgroundMid: Color(0xFFF0F0EA),
    backgroundNear: Color(0xFFE8E8E2),
    surface: Color(0xFFFFFFFF),
    denseSurface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x30000000),
    primaryText: Color(0xFF171717),
    secondaryText: Color(0xCC171717),
    mutedText: Color(0xFF4B5563),
    primaryAccent: Color(0xFF2563EB),
    secondaryAccent: Color(0xFF7C3AED),
    focusAccent: Color(0xFF1D4ED8),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    glowIntensity: 0.3,
  );

  // Pure-white page — lightest possible load; no glow at all.
  static const lightLite = CosmoThemeTokens(
    background: Color(0xFFFFFFFF),
    backgroundMid: Color(0xFFF5F5F5),
    backgroundNear: Color(0xFFEBEBEB),
    surface: Color(0xFFF5F8FF),
    denseSurface: Color(0xFFFFFFFF),
    surfaceBorder: Color(0x40000000),
    primaryText: Color(0xFF0D1117),
    secondaryText: Color(0xCC0D1117),
    mutedText: Color(0xFF4B5563),
    primaryAccent: Color(0xFF2563EB),
    secondaryAccent: Color(0xFF7C3AED),
    focusAccent: Color(0xFF1D4ED8),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    glowIntensity: 0.0,
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
