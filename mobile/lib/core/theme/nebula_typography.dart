import 'package:flutter/material.dart';

/// Typography tokens — single source of truth for **all** text styles
/// in the app.
///
/// Why ThemeExtension and not a global static class?
///
/// 1. **DIP**: widgets read `Theme.of(context).extension<NebulaTypography>()`
///    and depend on the abstraction, not on a hardcoded set of sizes.
/// 2. **OCP**: adding a desktop scale, a compact mode, a high-density
///    variant — register another `NebulaTypography` instance, theme picks
///    it up. Widgets never change.
/// 3. **SRP**: this file knows numbers and weights. `CosmoThemeTokens`
///    knows colors. Surface profiles know recipes. Nothing overlaps.
///
/// Naming follows Material 3 conventions but the scale is custom-tuned
/// for the Nebula language: tighter line height, more weight contrast.
class NebulaTypography extends ThemeExtension<NebulaTypography> {
  final TextStyle displayL; // 28, w700 — hero screen title (Студия / Зарплата)
  final TextStyle displayM; // 24, w700 — secondary screen title (Настройки)
  final TextStyle titleL;   // 20, w700 — section heading
  final TextStyle titleM;   // 18, w700 — card title
  final TextStyle titleS;   // 15, w600 — list item title, primary button
  final TextStyle bodyL;    // 15, w400 — body
  final TextStyle bodyM;    // 14, w400 — default body
  final TextStyle bodyS;    // 13, w400 — small body, secondary hint
  final TextStyle labelM;   // 12, w500 — form label, caption
  final TextStyle labelS;   // 11, w400 — tiny meta
  final TextStyle overline; // 10, w600, ls 0.8 — UPPERCASE section dividers
  final TextStyle mono;     // 12, w500, monospace — time / numeric data

  const NebulaTypography({
    required this.displayL,
    required this.displayM,
    required this.titleL,
    required this.titleM,
    required this.titleS,
    required this.bodyL,
    required this.bodyM,
    required this.bodyS,
    required this.labelM,
    required this.labelS,
    required this.overline,
    required this.mono,
  });

  /// Mobile-default scale. Used in light AND dark themes — typography is
  /// theme-independent (color is applied by the widget consuming the style).
  ///
  /// Every style carries `leadingDistribution: even`: SpaceGrotesk puts the
  /// extra line-height below the baseline by default, which visually sinks
  /// single-line labels inside fixed-height chips/buttons. Even distribution
  /// keeps text optically centered app-wide.
  static const NebulaTypography mobile = NebulaTypography(
    displayL: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 28,
      fontWeight: FontWeight.w700,
      height: 1.15,
      letterSpacing: -0.4,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    displayM: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.18,
      letterSpacing: -0.3,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleL: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.22,
      letterSpacing: -0.2,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleM: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 18,
      fontWeight: FontWeight.w700,
      height: 1.25,
      letterSpacing: -0.15,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    titleS: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.3,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyL: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 15,
      fontWeight: FontWeight.w400,
      height: 1.4,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyM: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.4,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    bodyS: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 13,
      fontWeight: FontWeight.w400,
      height: 1.4,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelM: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.3,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    labelS: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.3,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    overline: TextStyle(
      fontFamily: 'SpaceGrotesk',
      fontSize: 10,
      fontWeight: FontWeight.w600,
      height: 1.2,
      letterSpacing: 0.8,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    mono: TextStyle(
      fontFamily: 'SpaceMono',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.25,
      letterSpacing: 0.2,
      leadingDistribution: TextLeadingDistribution.even,
    ),
  );

  /// Desktop scale — slightly larger headings, same body. Tune one place
  /// to make the whole desktop UI breathe.
  static final NebulaTypography desktop = mobile.copyWith(
    displayL: mobile.displayL.copyWith(fontSize: 32),
    displayM: mobile.displayM.copyWith(fontSize: 27),
    titleL: mobile.titleL.copyWith(fontSize: 22),
    titleM: mobile.titleM.copyWith(fontSize: 19),
  );

  /// Convenience helper: read typography for the current context.
  /// Falls back to mobile if no extension is registered (test-friendly).
  static NebulaTypography of(BuildContext context) =>
      Theme.of(context).extension<NebulaTypography>() ?? mobile;

  @override
  NebulaTypography copyWith({
    TextStyle? displayL,
    TextStyle? displayM,
    TextStyle? titleL,
    TextStyle? titleM,
    TextStyle? titleS,
    TextStyle? bodyL,
    TextStyle? bodyM,
    TextStyle? bodyS,
    TextStyle? labelM,
    TextStyle? labelS,
    TextStyle? overline,
    TextStyle? mono,
  }) {
    return NebulaTypography(
      displayL: displayL ?? this.displayL,
      displayM: displayM ?? this.displayM,
      titleL: titleL ?? this.titleL,
      titleM: titleM ?? this.titleM,
      titleS: titleS ?? this.titleS,
      bodyL: bodyL ?? this.bodyL,
      bodyM: bodyM ?? this.bodyM,
      bodyS: bodyS ?? this.bodyS,
      labelM: labelM ?? this.labelM,
      labelS: labelS ?? this.labelS,
      overline: overline ?? this.overline,
      mono: mono ?? this.mono,
    );
  }

  @override
  NebulaTypography lerp(ThemeExtension<NebulaTypography>? other, double t) {
    if (other is! NebulaTypography) return this;
    return NebulaTypography(
      displayL: TextStyle.lerp(displayL, other.displayL, t)!,
      displayM: TextStyle.lerp(displayM, other.displayM, t)!,
      titleL: TextStyle.lerp(titleL, other.titleL, t)!,
      titleM: TextStyle.lerp(titleM, other.titleM, t)!,
      titleS: TextStyle.lerp(titleS, other.titleS, t)!,
      bodyL: TextStyle.lerp(bodyL, other.bodyL, t)!,
      bodyM: TextStyle.lerp(bodyM, other.bodyM, t)!,
      bodyS: TextStyle.lerp(bodyS, other.bodyS, t)!,
      labelM: TextStyle.lerp(labelM, other.labelM, t)!,
      labelS: TextStyle.lerp(labelS, other.labelS, t)!,
      overline: TextStyle.lerp(overline, other.overline, t)!,
      mono: TextStyle.lerp(mono, other.mono, t)!,
    );
  }
}
