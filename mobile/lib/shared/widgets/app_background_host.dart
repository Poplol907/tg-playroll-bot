import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_visual_mode.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import 'ascii_water_background.dart';
import 'nebula_background.dart';
import 'path_field_background.dart';

enum AppDarkBackground {
  nebula,
  asciiWater,
}

/// Single background entry point for app screens.
class AppBackgroundHost extends ConsumerWidget {
  final Widget child;
  final bool interactive;
  final AppDarkBackground darkBackground;

  const AppBackgroundHost({
    super.key,
    required this.child,
    this.interactive = true,
    this.darkBackground = AppDarkBackground.nebula,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visualMode = ref.watch(appVisualModeProvider);

    // The background WRAPS the content so the interactive backgrounds (ASCII
    // water reveal-on-touch, Nebula parallax) receive pointer events as they
    // pass through to the child. Switching theme swaps the wrapper type and
    // rebuilds the subtree; the PageView's pager position is re-synced in the
    // shell (see _buildMobileLayout) so that rebuild never scrolls the pager.
    return switch (visualMode) {
      AppVisualMode.darkInternals => switch (darkBackground) {
          AppDarkBackground.nebula => NebulaBackground(
              interactive: interactive,
              child: child,
            ),
          AppDarkBackground.asciiWater => AsciiWaterBackground(child: child),
        },
      // Ambient (non-interactive) animation: the stripes drift slowly and
      // soft glints glide along them — mirrors the dark theme's living
      // background. Reduce-motion freezes it via PathFieldBackground itself.
      AppVisualMode.lightLite => PathFieldBackground(
          tokens: CosmoThemeTokens.lightLite,
          animated: true,
          child: child,
        ),
    };
  }
}
