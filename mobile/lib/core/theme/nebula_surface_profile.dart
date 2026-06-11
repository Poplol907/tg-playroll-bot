import 'package:flutter/material.dart';

import 'cosmo_theme_tokens.dart';
import 'nebula_alpha.dart';
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

  /// Same material color, but suitable for surfaces that sit above live
  /// content. Cards in normal page flow may stay translucent; sheets/dialogs
  /// must occlude the route below so text never bleeds through.
  Color get occludingFill =>
      fill.withValues(alpha: NebulaAlpha.occludingSurface);
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
      NebulaSurfaceProfile.nav => isLight
          ? tokens.denseSurface.withValues(alpha: NebulaAlpha.solid)
          : tokens.surface,
      // Status fills sit on the page background. On light, the dark-tuned
      // 0.12 tint washes a saturated accent into pastel — bump to subtle
      // (0.18) so the chip actually reads as that accent. Dark stays subtle.
      NebulaSurfaceProfile.status => semanticAccent.withValues(
          alpha: isLight ? NebulaAlpha.subtle : NebulaAlpha.surface),
      NebulaSurfaceProfile.frostedSmall => tokens.denseSurface,
    };

    final border = switch (this) {
      // Crisper accent edges on light so the surface doesn't dissolve into
      // the white page; dark keeps its softer, tuned borders.
      _ when hasAccent => semanticAccent.withValues(
          alpha: isLight ? NebulaAlpha.medium : NebulaAlpha.accent),
      NebulaSurfaceProfile.status => semanticAccent.withValues(
          alpha: isLight ? NebulaAlpha.strong : NebulaAlpha.medium),
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
              color: Colors.black.withValues(alpha: NebulaAlpha.mist),
              blurRadius: 16,
              spreadRadius: -3,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: NebulaAlpha.whisper),
              blurRadius: 36,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withValues(alpha: NebulaAlpha.border),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ];

    if (this != NebulaSurfaceProfile.status && !hasAccent) return base;

    final accentHaloAlpha =
        (isLight ? NebulaAlpha.whisper : NebulaAlpha.surface) *
            (isLight ? 1.0 : tokens.glowIntensity);

    return [
      ...base,
      BoxShadow(
        color: accent.withValues(alpha: accentHaloAlpha),
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
          // Matte glass: a gentle top-light instead of a glossy hot streak.
          // The highlight is dimmer and falls off smoothly, so light surfaces
          // read as frosted/satin rather than polished.
          ? [
              Colors.white.withValues(alpha: NebulaAlpha.medium),
              Colors.white.withValues(alpha: NebulaAlpha.whisper),
              Colors.transparent,
              Colors.black.withValues(alpha: NebulaAlpha.whisper),
            ]
          : [
              Colors.white.withValues(alpha: NebulaAlpha.mist),
              Colors.white.withValues(alpha: NebulaAlpha.whisper),
              Colors.transparent,
              Colors.black.withValues(alpha: NebulaAlpha.mist),
            ],
      stops: const [0.0, 0.22, 0.55, 1.0],
    );
  }
}
