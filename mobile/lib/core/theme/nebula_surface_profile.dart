import 'package:flutter/material.dart';

import 'cosmo_theme_tokens.dart';
import 'nebula_tokens.dart';

enum NebulaBlurPolicy {
  none,
  explicit,
}

enum NebulaSurfaceProfile {
  card,
  panel,
  modal,
  input,
  nav,
  status,
  frostedSmall,
}

class NebulaSurfaceStyle {
  final Color fill;
  final Color border;
  final double borderWidth;
  final double radius;
  final EdgeInsetsGeometry padding;
  final List<BoxShadow> shadows;
  final NebulaBlurPolicy blurPolicy;
  final double blurSigma;
  final LinearGradient? sheen;
  final bool paintSpecularBorder;

  const NebulaSurfaceStyle({
    required this.fill,
    required this.border,
    required this.borderWidth,
    required this.radius,
    required this.padding,
    required this.shadows,
    required this.blurPolicy,
    required this.blurSigma,
    this.sheen,
    this.paintSpecularBorder = true,
  });
}

extension NebulaSurfaceProfileResolver on NebulaSurfaceProfile {
  NebulaSurfaceStyle resolve(BuildContext context, {Color? accent}) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<CosmoThemeTokens>() ?? CosmoThemeTokens.darkInternals;
    final isLight = theme.brightness == Brightness.light;
    final semanticAccent = accent ?? tokens.primaryAccent;
    final hasAccent = accent != null;

    final fill = switch (this) {
      NebulaSurfaceProfile.card => tokens.surface,
      NebulaSurfaceProfile.panel => tokens.denseSurface,
      NebulaSurfaceProfile.modal => tokens.denseSurface,
      NebulaSurfaceProfile.input => tokens.denseSurface,
      NebulaSurfaceProfile.nav =>
        isLight ? tokens.denseSurface.withValues(alpha: 0.96) : tokens.surface,
      NebulaSurfaceProfile.status => isLight
          ? semanticAccent.withValues(alpha: 0.10)
          : semanticAccent.withValues(alpha: 0.12),
      NebulaSurfaceProfile.frostedSmall => tokens.denseSurface,
    };

    final border = switch (this) {
      _ when hasAccent => semanticAccent.withValues(
          alpha: isLight ? 0.32 : 0.38,
        ),
      NebulaSurfaceProfile.status => semanticAccent.withValues(
          alpha: isLight ? 0.34 : 0.42,
        ),
      NebulaSurfaceProfile.input => tokens.surfaceBorder,
      NebulaSurfaceProfile.frostedSmall => tokens.surfaceBorder,
      _ => tokens.surfaceBorder,
    };

    return NebulaSurfaceStyle(
      fill: fill,
      border: border,
      borderWidth: _borderWidth,
      radius: _radius,
      padding: _padding,
      shadows: _shadows(isLight, tokens, semanticAccent, hasAccent),
      blurPolicy: this == NebulaSurfaceProfile.frostedSmall
          ? NebulaBlurPolicy.explicit
          : NebulaBlurPolicy.none,
      blurSigma: this == NebulaSurfaceProfile.frostedSmall
          ? NebulaTokens.blurMedium
          : 0,
      sheen: _sheen(isLight),
      paintSpecularBorder: this != NebulaSurfaceProfile.input,
    );
  }

  double get _borderWidth => switch (this) {
        NebulaSurfaceProfile.input => NebulaTokens.inputBorderWidth,
        NebulaSurfaceProfile.nav => 0.8,
        _ => 1,
      };

  double get _radius => switch (this) {
        NebulaSurfaceProfile.input => NebulaTokens.radiusSM,
        NebulaSurfaceProfile.card => NebulaTokens.radiusMD,
        NebulaSurfaceProfile.panel => NebulaTokens.radiusLG,
        NebulaSurfaceProfile.modal => NebulaTokens.radiusLG,
        NebulaSurfaceProfile.nav => NebulaTokens.radiusLG,
        NebulaSurfaceProfile.status => NebulaTokens.radiusSM,
        NebulaSurfaceProfile.frostedSmall => NebulaTokens.radiusMD,
      };

  EdgeInsetsGeometry get _padding => switch (this) {
        NebulaSurfaceProfile.input => EdgeInsets.zero,
        NebulaSurfaceProfile.nav => const EdgeInsets.all(NebulaTokens.sp8),
        NebulaSurfaceProfile.status => const EdgeInsets.symmetric(
            horizontal: NebulaTokens.sp12,
            vertical: NebulaTokens.sp4,
          ),
        _ => const EdgeInsets.all(NebulaTokens.sp20),
      };

  List<BoxShadow> _shadows(
    bool isLight,
    CosmoThemeTokens tokens,
    Color accent,
    bool hasAccent,
  ) {
    if (this == NebulaSurfaceProfile.input) return const [];
    if (this == NebulaSurfaceProfile.nav) return const [];

    final base = isLight
        ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              spreadRadius: -3,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 36,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.24),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ];

    if (this != NebulaSurfaceProfile.status && !hasAccent) return base;

    return [
      ...base,
      BoxShadow(
        color: accent.withValues(
          alpha: (isLight ? 0.06 : 0.12) * (isLight ? 1 : tokens.glowIntensity),
        ),
        blurRadius: isLight ? 14 : 18,
        offset: Offset.zero,
      ),
    ];
  }

  LinearGradient _sheen(bool isLight) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isLight
          ? [
              Colors.white.withValues(alpha: 0.70),
              Colors.white.withValues(alpha: 0.08),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.025),
            ]
          : [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.025),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.07),
            ],
      stops: const [0.0, 0.22, 0.55, 1.0],
    );
  }
}
