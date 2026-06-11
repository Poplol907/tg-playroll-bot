import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppVisualMode {
  darkInternals,
  lightLite,
}

final appVisualModeProvider = StateProvider<AppVisualMode>((ref) {
  return AppVisualMode.darkInternals;
});
