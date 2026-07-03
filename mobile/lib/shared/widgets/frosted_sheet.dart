import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_tokens.dart';

/// Canonical frosted-glass bottom sheet entry point.
///
/// A flat dark scrim (black @ 0.60) made every translucent Nebula island
/// behind a sheet suddenly expose its borders against the darkened page —
/// the background read as a collection of outlined boxes. The frosted
/// barrier instead blurs the route below IN SYNC with the sheet animation:
/// the page melts into one soft plane and the sheet rises out of mist,
/// which is the Nebula material language for modality.
///
/// Use this instead of [showModalBottomSheet] everywhere. The architecture
/// tests pin both `showModalBottomSheet` and `ModalBottomSheetRoute` to this
/// file, so new call sites cannot silently reintroduce flat scrims.
Future<T?> showFrostedSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = true,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push(FrostedSheetRoute<T>(
    builder: builder,
    capturedThemes:
        InheritedTheme.capture(from: context, to: navigator.context),
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    constraints: constraints,
    backgroundColor: Colors.transparent,
    // Lighter tint than the old flat scrim: the blur carries the separation,
    // the tint only adds depth.
    modalBarrierColor: Colors.black.withValues(alpha: NebulaAlpha.accent),
    barrierLabel: MaterialLocalizations.of(context).scrimLabel,
  ));
}

/// Shows a dialog over the same frosted barrier as [showFrostedSheet] —
/// confirm dialogs melt the page into mist instead of spotlighting island
/// borders with a flat dark scrim.
Future<T?> showFrostedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  return navigator.push(FrostedDialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: NebulaAlpha.accent),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  ));
}

/// Wraps a route's stock barrier with an animation-synced frost: sigma rides
/// the route animation 0 → [NebulaTokens.blurDense], so open/dismiss/drag all
/// keep the blur in step — no sudden darkening, fully interruptible.
Widget _frostBarrier(ModalRoute<dynamic> route, Widget barrier) {
  final anim = route.animation;
  if (anim == null) return barrier;
  return AnimatedBuilder(
    animation: anim,
    builder: (context, child) {
      final sigma =
          NebulaTokens.blurDense * Curves.easeOut.transform(anim.value);
      // Skip the saveLayer entirely while the blur is imperceptible.
      if (sigma < 0.5) return child!;
      return BackdropFilter(
        key: const ValueKey('frosted-sheet-barrier'),
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      );
    },
    child: barrier,
  );
}

/// [ModalBottomSheetRoute] whose barrier frosts the content beneath it.
class FrostedSheetRoute<T> extends ModalBottomSheetRoute<T> {
  FrostedSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    super.capturedThemes,
    super.isDismissible,
    super.enableDrag,
    super.useSafeArea,
    super.constraints,
    super.backgroundColor,
    super.modalBarrierColor,
    super.barrierLabel,
    super.settings,
  });

  @override
  Widget buildModalBarrier() => _frostBarrier(this, super.buildModalBarrier());
}

/// [DialogRoute] with the same frosted barrier as [FrostedSheetRoute].
class FrostedDialogRoute<T> extends DialogRoute<T> {
  FrostedDialogRoute({
    required super.context,
    required super.builder,
    super.barrierDismissible,
    super.barrierColor,
    super.barrierLabel,
    super.themes,
    super.settings,
  });

  @override
  Widget buildModalBarrier() => _frostBarrier(this, super.buildModalBarrier());
}
