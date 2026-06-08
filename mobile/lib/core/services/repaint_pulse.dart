import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Global "wake up and repaint" pulse.
///
/// Problem it solves: the animated backgrounds (ascii water, path field,
/// nebula) stop their tickers when idle to save battery. When a modal /
/// dialog / sheet closes, its barrier fades out — but if nothing schedules
/// a fresh frame afterward, the last composited frame (still showing the
/// dimmed barrier) lingers on screen until the user taps (which wakes the
/// background via its pointer listener). Result: "screen stays dark until
/// I click".
///
/// Fix: a single [RepaintPulse.notifier] that backgrounds listen to. A
/// [RepaintPulseObserver] attached to the app's Navigator bumps it whenever
/// a route is popped/removed, forcing every listening background to paint a
/// couple of fresh frames and clear the stale dim.
class RepaintPulse {
  RepaintPulse._();

  /// Bumped every time the route stack shrinks. Backgrounds repaint on change.
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);

  /// Force a short burst of frames so idle painters refresh.
  static void pulse() {
    notifier.value++;
    // Schedule a follow-up frame on the next tick too, so a painter that
    // recomputes on the current frame still gets a clean second frame.
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      notifier.value++;
    });
  }
}

/// Navigator observer that pulses a repaint whenever a route is dismissed.
/// Attach to GoRouter's `observers` so it sees modal/dialog/sheet pops
/// (they push onto the same Navigator).
class RepaintPulseObserver extends NavigatorObserver {
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RepaintPulse.pulse();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    RepaintPulse.pulse();
    super.didRemove(route, previousRoute);
  }
}
