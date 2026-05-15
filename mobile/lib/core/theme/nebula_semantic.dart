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
  factory SemanticRole.fromBase(Color base, {Color? contrast}) => SemanticRole(
        base: base,
        tint: base.withValues(alpha: NebulaAlpha.surface),
        border: base.withValues(alpha: NebulaAlpha.accent),
        glow: base.withValues(alpha: NebulaAlpha.subtle),
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
    return NebulaSemantic(
      primary: SemanticRole.fromBase(t.primaryAccent),
      info: SemanticRole.fromBase(t.focusAccent),
      success: SemanticRole.fromBase(t.success),
      warning: SemanticRole.fromBase(t.warning),
      danger: SemanticRole.fromBase(t.error),
      neutral: SemanticRole.fromBase(
        // mistWhite for dark, mutedText for light — picked by the active token
        t.mutedText == NebulaColors.dimText
            ? NebulaColors.mistWhite
            : t.mutedText,
        contrast: t.mutedText,
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
