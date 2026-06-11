import 'package:flutter/material.dart';

import 'cosmo_theme_tokens.dart';
import 'nebula_alpha.dart';
import 'nebula_colors.dart';

/// A semantic role — a complete recipe for "danger" or "success" without
/// the caller ever writing the alpha value by hand. Use `NebulaSemantic.of`
/// in widgets and let the role pick the right tint/border/glow.
///
/// One `SemanticRole` carries everything a status surface or icon callout
/// needs: pure base color, soft tint for fills, slightly stronger border,
/// glow color, and high-contrast variant for text on the tint.
@immutable
class SemanticRole {
  final Color base;
  final Color tint;
  final Color border;
  final Color glow;
  final Color contrast;

  const SemanticRole({
    required this.base,
    required this.tint,
    required this.border,
    required this.glow,
    required this.contrast,
  });

  /// Build a role from a single base color and the global alpha tokens.
  /// Call sites get cohesive surfaces without ever picking an alpha value.
  ///
  /// On a LIGHT background a saturated accent at the dark-tuned alpha (0.12
  /// fill / 0.35 border) washes out into pastel mush. Light therefore uses
  /// a denser tint + crisper border so the accent actually *accents* — this
  /// matches the reference pill spec (≈0.18 fill, ≈0.60 border, saturated
  /// text). Dark keeps its tuned, subtle values. Same recipe, theme-aware
  /// density — the philosophy holds, only the alpha tier shifts.
  factory SemanticRole.fromBase(
    Color base, {
    Color? contrast,
    bool isLight = false,
  }) =>
      SemanticRole(
        base: base,
        tint: base.withValues(
            alpha: isLight ? NebulaAlpha.subtle : NebulaAlpha.surface),
        border: base.withValues(
            alpha: isLight ? NebulaAlpha.strong : NebulaAlpha.accent),
        glow: base.withValues(
            alpha: isLight ? NebulaAlpha.accent : NebulaAlpha.subtle),
        contrast: contrast ?? base,
      );
}

/// Catalogue of semantic roles for the app. The five roles cover every
/// status / message / call-out the UI needs to express.
///
/// SOLID notes:
/// - **DIP**: `StatusBadge`, `IconCallout`, `AppErrorCard` read the role
///   from `NebulaSemantic.of(context).danger`, never reach for a color.
/// - **OCP**: rebrand the studio? Override these factories once. Every
///   status surface inherits the new look.
/// - **SRP**: this file maps `intent → color recipe`. Nothing else.
class NebulaSemantic extends ThemeExtension<NebulaSemantic> {
  final SemanticRole primary;
  final SemanticRole info;
  final SemanticRole success;
  final SemanticRole warning;
  final SemanticRole danger;
  final SemanticRole neutral;

  const NebulaSemantic({
    required this.primary,
    required this.info,
    required this.success,
    required this.warning,
    required this.danger,
    required this.neutral,
  });

  /// Build the role catalogue out of the active `CosmoThemeTokens`.
  /// This keeps light and dark themes in sync automatically.
  factory NebulaSemantic.fromTokens(CosmoThemeTokens t) {
    // Dark theme uses NebulaColors.dimText as its muted token; the light
    // themes substitute their own muted grey. That single difference is a
    // reliable, context-free brightness probe so accent density tracks theme.
    final isLight = t.mutedText != NebulaColors.dimText;
    return NebulaSemantic(
      primary: SemanticRole.fromBase(t.primaryAccent, isLight: isLight),
      info: SemanticRole.fromBase(t.focusAccent, isLight: isLight),
      success: SemanticRole.fromBase(t.success, isLight: isLight),
      warning: SemanticRole.fromBase(t.warning, isLight: isLight),
      danger: SemanticRole.fromBase(t.error, isLight: isLight),
      neutral: SemanticRole.fromBase(
        // mistWhite for dark, mutedText for light — picked by the active token
        isLight ? t.mutedText : NebulaColors.mistWhite,
        contrast: t.mutedText,
        isLight: isLight,
      ),
    );
  }

  /// Pick the role that matches an arbitrary intent string. Useful when
  /// the intent is data-driven (lesson status, payload field, etc.).
  SemanticRole byIntent(SemanticIntent intent) {
    return switch (intent) {
      SemanticIntent.primary => primary,
      SemanticIntent.info => info,
      SemanticIntent.success => success,
      SemanticIntent.warning => warning,
      SemanticIntent.danger => danger,
      SemanticIntent.neutral => neutral,
    };
  }

  /// Convenience accessor — falls back to a dark-theme-flavoured catalogue
  /// if no extension is registered (test-friendly).
  static NebulaSemantic of(BuildContext context) =>
      Theme.of(context).extension<NebulaSemantic>() ??
      NebulaSemantic.fromTokens(CosmoThemeTokens.darkInternals);

  @override
  NebulaSemantic copyWith({
    SemanticRole? primary,
    SemanticRole? info,
    SemanticRole? success,
    SemanticRole? warning,
    SemanticRole? danger,
    SemanticRole? neutral,
  }) {
    return NebulaSemantic(
      primary: primary ?? this.primary,
      info: info ?? this.info,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      neutral: neutral ?? this.neutral,
    );
  }

  @override
  NebulaSemantic lerp(ThemeExtension<NebulaSemantic>? other, double t) {
    // Roles are derived from theme tokens, which already lerp on their
    // own — picking the "to" side here avoids double-interpolation noise.
    if (other is! NebulaSemantic) return this;
    return t < 0.5 ? this : other;
  }
}

enum SemanticIntent { primary, info, success, warning, danger, neutral }
