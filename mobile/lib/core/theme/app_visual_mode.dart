import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppVisualMode {
  darkInternals,
  lightLite,
}

/// Storage key for the persisted theme choice. Seeded into the provider at
/// startup (see main.dart) and written whenever the user toggles the theme.
const String kVisualModeStorageKey = 'visual_mode';

/// Parse a stored value back into a mode, defaulting to dark.
AppVisualMode visualModeFromStored(String? raw) {
  return AppVisualMode.values.firstWhere(
    (m) => m.name == raw,
    orElse: () => AppVisualMode.darkInternals,
  );
}

final appVisualModeProvider = StateProvider<AppVisualMode>((ref) {
  return AppVisualMode.darkInternals;
});
