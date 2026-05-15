/// Barrel export for design-system primitives.
///
/// These widgets are **dumb renderers** — they accept theme-derived styles
/// and semantic intent, and render layout. They never invent colors,
/// alphas, font sizes, or padding.
///
/// Add new primitives here only when a UI pattern repeats in 2+ features
/// AND no existing primitive fits. Otherwise compose existing ones.
library;

export 'action_row.dart';
export 'icon_callout.dart';
export 'metric_stat.dart';
export 'status_badge.dart';
