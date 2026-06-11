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
    surface: Color(0xE60F1528),
    denseSurface: Color(0xF01B2444),
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

  // Warm sand-pearl page — light, premium, but not washed out. Accents reuse
  // the same canonical NebulaColors as dark mode so statuses don't drift
  // between screens or themes.
  static const lightLite = CosmoThemeTokens(
    background: Color(0xFFFFF8EC),
    backgroundMid: Color(0xFFFFF1DA),
    backgroundNear: Color(0xFFF5DFC0),
    surface: Color(0xF2FFFDF7),
    denseSurface: Color(0xFAFFFCF3),
    surfaceBorder: Color(0x55D8B98A),
    primaryText: Color(0xFF211A12),
    secondaryText: Color(0xCC211A12),
    mutedText: Color(0xFF6F6254),
    primaryAccent: NebulaColors.stellarBlue,
    secondaryAccent: NebulaColors.nebulaPurple,
    focusAccent: NebulaColors.auroraCyan,
    success: NebulaColors.successMint,
    warning: NebulaColors.warningAmber,
    error: NebulaColors.errorRose,
    glowIntensity: 0.18,
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
