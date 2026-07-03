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

/// [ModalBottomSheetRoute] whose barrier frosts the content beneath it.
///
/// The blur sigma follows the route animation (0 → [NebulaTokens.blurDense]),
/// so opening, dismissing and interactive drag-to-close all keep the barrier
/// in step with the sheet — no sudden darkening, fully interruptible.
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
  Widget buildModalBarrier() {
    final barrier = super.buildModalBarrier();
    final anim = animation;
    if (anim == null) return barrier;
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final sigma =
            NebulaTokens.blurDense * Curves.easeOut.transform(anim.value);
        // Skip the saveLayer entirely while the blur is imperceptible.
        if (sigma < 0.5) return child!;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: child,
        );
      },
      child: barrier,
    );
  }
}
