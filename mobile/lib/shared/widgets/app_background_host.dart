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

    // The background is a Stack sibling BEHIND the content — NOT a parent
    // wrapping it. Switching themes swaps the background widget *type*
    // (ascii-water ↔ path-field); if that wrapped the content, Flutter would
    // tear down and rebuild the whole subtree (incl. the PageView), which
    // both kills the theme cross-fade and scrolls the pager. As a sibling,
    // only the background layer rebuilds; the content keeps its element/state.
    //
    // AnimatedSwitcher cross-dissolves the background on theme change, so the
    // new theme "spreads" across the app instead of hard-cutting. Theme colors
    // cross-fade independently via MaterialApp's AnimatedTheme.
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(
            key: ValueKey('$visualMode-$darkBackground'),
            child: _background(visualMode),
          ),
        ),
        child,
      ],
    );
  }

  Widget _background(AppVisualMode visualMode) {
    const empty = SizedBox.expand();
    return switch (visualMode) {
      AppVisualMode.darkInternals => switch (darkBackground) {
          AppDarkBackground.nebula =>
            NebulaBackground(interactive: interactive, child: empty),
          AppDarkBackground.asciiWater =>
            const AsciiWaterBackground(child: empty),
        },
      // Ambient (non-interactive) animation: the stripes drift slowly and
      // soft glints glide along them — mirrors the dark theme's living
      // background. Reduce-motion freezes it via PathFieldBackground itself.
      AppVisualMode.lightLite => const PathFieldBackground(
          tokens: CosmoThemeTokens.lightLite,
          animated: true,
          child: empty,
        ),
    };
  }
}
