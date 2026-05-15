/// Single source of truth for opacity / alpha values across the app.
///
/// Naming is intentional and semantic — not numeric — so feature code
/// stays readable when intensity is tweaked globally:
///
///   color.withValues(alpha: NebulaAlpha.surface)
///
/// is better than:
///
///   color.withValues(alpha: 0.12)
///
/// Tweaking the visual feel of the whole app (e.g. "глянец стекла плотнее")
/// becomes a one-line change here, not a hunt-and-replace across the codebase.
///
/// The ten tiers are chosen so that distribution in `lib/` collapses onto
/// them cleanly. If you find yourself reaching for a value that does not
/// fit any tier — STOP and either pick the nearest tier, or open a
/// discussion before adding a new one.
abstract class NebulaAlpha {
  /// Barely visible — distant gradient stops, ambient corner glows.
  /// (~0.04)
  static const double whisper = 0.04;

  /// Subtle background tint — neutral surface fills on dark theme,
  /// secondary chip backgrounds.
  /// (~0.08)
  static const double mist = 0.08;

  /// Default card / surface fill alpha.
  /// (~0.12)
  static const double surface = 0.12;

  /// Subtle accent — hover tints, soft badge fills, inactive chips.
  /// (~0.18)
  static const double subtle = 0.18;

  /// Standard divider / border / muted indicator.
  /// (~0.25)
  static const double border = 0.25;

  /// Accent border, active hover state, soft glow halo.
  /// (~0.35)
  static const double accent = 0.35;

  /// Strong accent border, focused field outline, prominent badge edge.
  /// (~0.45)
  static const double medium = 0.45;

  /// Body of a glow, secondary text overlay, modal scrim sheen.
  /// (~0.60)
  static const double strong = 0.60;

  /// Disabled overlay, very dark scrim, near-opaque caption text.
  /// (~0.75)
  static const double high = 0.75;

  /// Near opaque — modal chrome, primary scrim. Reserve for true
  /// foreground surfaces, never for accents.
  /// (~0.95)
  static const double solid = 0.95;
}
