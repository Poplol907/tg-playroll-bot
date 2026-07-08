import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/platform/app_platform.dart';
import '../../core/services/repaint_pulse.dart';
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
  // ROOT по умолчанию: вложенный навигатор шелла живёт ВНУТРИ SafeArea,
  // поэтому его барьер физически не покрывал полосу статус-бара — над
  // Dynamic Island оставался незаблюренный «кусок» шелла. Root-оверлей
  // накрывает весь экран, и root-обсерверы (repaint pulse, bottom bar)
  // видят эти роуты.
  bool useRootNavigator = true,
  BoxConstraints? constraints,
}) {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final future = navigator.push(FrostedSheetRoute<T>(
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
  // Шиты часто открываются на ВЛОЖЕННОМ навигаторе шелла, мимо
  // RepaintPulseObserver (он висит только на корневом). Без пульса спящий
  // ascii-фон не рисует ни одного кадра после ухода барьера, и последний
  // затемнённый кадр висит «до тапа». Пульсуем по завершении роута сами.
  future.whenComplete(RepaintPulse.pulse);
  return future;
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
  final future = navigator.push(FrostedDialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    barrierColor: Colors.black.withValues(alpha: NebulaAlpha.accent),
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  ));
  // См. showFrostedSheet: будим спящие фоны после закрытия.
  future.whenComplete(RepaintPulse.pulse);
  return future;
}

/// Wraps a route's stock barrier with an animation-synced frost: sigma rides
/// the route animation 0 → [NebulaTokens.blurDense], so open/dismiss/drag all
/// keep the blur in step — no sudden darkening, fully interruptible.
Widget _frostBarrier(ModalRoute<dynamic> route, Widget barrier) {
  final anim = route.animation;
  if (anim == null) return barrier;
  // Android: a full-screen BackdropFilter whose sigma changes every frame of
  // the transition defeats blur caching and janks mid-range GPUs. There the
  // barrier rides on the tint alone while in flight, and the settled blur
  // switches on once, when the route is nearly open; dragging a sheet pulls
  // anim.value back under the threshold, so the interactive phase pays no
  // blur at all. iOS/desktop keep the animation-synced frost.
  final lite = AppPlatform.liteGraphics;
  return AnimatedBuilder(
    animation: anim,
    builder: (context, child) {
      final double sigma;
      if (lite) {
        if (anim.value < 0.85) return child!;
        sigma = NebulaTokens.blurDense;
      } else {
        sigma = NebulaTokens.blurDense * Curves.easeOut.transform(anim.value);
        // Skip the saveLayer entirely while the blur is imperceptible.
        if (sigma < 0.5) return child!;
      }
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

  @override
  void dispose() {
    super.dispose();
    // dispose происходит ПОСЛЕ завершения exit-анимации (future от push
    // резолвится ещё в начале reverse) — этот пульс гарантирует чистый
    // кадр, когда барьер уже физически снят, даже если фон успел уснуть.
    RepaintPulse.pulse();
  }
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

  @override
  void dispose() {
    super.dispose();
    RepaintPulse.pulse();
  }
}
