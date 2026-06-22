import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Controls whether the floating nav bar is shown over the current screen.
///
/// Two ways to drive it:
///   1. A push/detail screen wraps its body in [HideBottomBar] (manual).
///   2. [BottomBarHideObserver] tracks any modal-style route (sheet, dialog,
///      MistModal etc.) and flips the provider automatically — the bar
///      slides off the bottom while ANY modal is on the route stack and
///      slides back once the last one is dismissed.
final bottomBarVisibleProvider = StateProvider<bool>((ref) => true);

/// Navigator observer that auto-hides the floating bar whenever a modal-style
/// route is on top of the stack. Counts pushes/pops so nested modals work.
///
/// Why an observer, not per-modal wrapping: every detail screen in Cosmo
/// opens through `showModalBottomSheet` / `showDialog` from a different
/// context, and wrapping the modal's body in HideBottomBar can't reach the
/// shell's ProviderScope reliably. An observer attached to the SAME
/// Navigator that hosts the routes sees every push/pop without per-route
/// plumbing.
class BottomBarHideObserver extends NavigatorObserver {
  BottomBarHideObserver(this._setVisible);

  /// Called whenever the bar's visibility flips. Wire it to a provider
  /// notifier from the router's Provider scope.
  final void Function(bool visible) _setVisible;
  int _depth = 0;

  bool _isModal(Route<dynamic> route) {
    // ModalBottomSheetRoute, DialogRoute, PopupRoute and PageRouteBuilder
    // (the one we use for full-screen pushes) are all ModalRoute subclasses.
    // Skip the very first route (the shell itself) — it isn't a "modal".
    if (route is! ModalRoute) return false;
    if (route.isFirst) return false;
    return true;
  }

  void _sync() {
    _setVisible(_depth <= 0);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isModal(route)) {
      _depth++;
      _sync();
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isModal(route) && _depth > 0) {
      _depth--;
      _sync();
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isModal(route) && _depth > 0) {
      _depth--;
      _sync();
    }
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final oldModal = oldRoute != null && _isModal(oldRoute);
    final newModal = newRoute != null && _isModal(newRoute);
    if (oldModal && !newModal) _depth = (_depth - 1).clamp(0, 1 << 30);
    if (!oldModal && newModal) _depth++;
    _sync();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
