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

/// Controls whether the floating TOP island (month pill) is shown.
///
/// Unlike [bottomBarVisibleProvider], this is NOT driven by "any modal is
/// open". A bottom sheet at its initial half-screen size shouldn't hide the
/// month — the user is still interacting with the page. Only when the sheet
/// is dragged up to full-screen does the top chrome retract, to give the
/// content the entire viewport.
///
/// Wire it by wrapping a [DraggableScrollableSheet] with
/// [HideTopIslandOnFullSheetExpand], which flips the provider once the
/// sheet's extent crosses [_fullExpandThreshold].
final topIslandVisibleProvider = StateProvider<bool>((ref) => true);

/// Extent threshold (0..1) at which a draggable sheet counts as "full
/// screen" for the purposes of hiding the top island. Slightly below 1.0
/// so a tiny gap during the spring animation still reads as fully expanded.
const double _fullExpandThreshold = 0.95;

/// Listens to [DraggableScrollableNotification]s bubbling up through its
/// subtree and toggles [topIslandVisibleProvider] when the sheet crosses
/// [_fullExpandThreshold]. Restores visibility on dispose so the island
/// always returns when the sheet pops.
///
/// Wrap the root of each [DraggableScrollableSheet] builder result with
/// this so the notification chain stays inside the modal's element tree
/// (notifications don't bubble across route boundaries).
class HideTopIslandOnFullSheetExpand extends ConsumerStatefulWidget {
  final Widget child;
  const HideTopIslandOnFullSheetExpand({super.key, required this.child});

  @override
  ConsumerState<HideTopIslandOnFullSheetExpand> createState() =>
      _HideTopIslandOnFullSheetExpandState();
}

class _HideTopIslandOnFullSheetExpandState
    extends ConsumerState<HideTopIslandOnFullSheetExpand> {
  bool _hidden = false;

  @override
  void dispose() {
    // Always restore the island when this widget leaves the tree — the
    // sheet might pop while still expanded, and the next route shouldn't
    // inherit a hidden island.
    if (_hidden) {
      final container = ProviderScope.containerOf(context, listen: false);
      Future.microtask(
        () => container.read(topIslandVisibleProvider.notifier).state = true,
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<DraggableScrollableNotification>(
      onNotification: (notification) {
        final shouldHide = notification.extent >= _fullExpandThreshold;
        if (shouldHide != _hidden) {
          _hidden = shouldHide;
          ref.read(topIslandVisibleProvider.notifier).state = !shouldHide;
        }
        // Let other listeners (snap animations, parent observers) see it too.
        return false;
      },
      child: widget.child,
    );
  }
}

/// Hide the floating nav bar while [show] is in flight, restore on completion.
///
/// Used by MistModal.show / AdaptiveModal.show / direct showModalBottomSheet
/// call sites so the bar always retracts when a sheet/dialog opens, even if
/// the observer-based path misses (e.g. modal pushed on a different
/// Navigator, theme-rebuild eats the depth counter, etc.).
///
/// Nests safely via a counter — opening a modal from inside another modal
/// keeps the bar hidden until BOTH have closed.
Future<T?> runWithBottomBarHidden<T>(
  BuildContext context,
  Future<T?> Function() show,
) async {
  ProviderContainer? container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } catch (_) {
    // No scope (test mode, isolated viewer) — just run the show fn.
    return show();
  }
  final notifier = container.read(bottomBarVisibleProvider.notifier);
  final wasVisible = notifier.state;
  if (wasVisible) notifier.state = false;
  try {
    return await show();
  } finally {
    if (wasVisible) notifier.state = true;
  }
}

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

  /// Live modal routes, tracked by identity instead of a depth counter.
  ///
  /// A counter is not replay-safe: during a go_router `go()` the Navigator
  /// diffs its pages and can push the NEW shell page while the old one is
  /// still in history — at that instant the new page is "not first", the old
  /// `isFirst`-based check classified it as a modal, and the matching
  /// didRemove of the old page (which IS first) never compensated. The
  /// leaked +1 kept the bar hidden forever after "открыть как педагог"
  /// (view-as). A set keyed by the route object cannot double-count and
  /// cannot leak on reordered push/remove events.
  final Set<Route<dynamic>> _modals = <Route<dynamic>>{};

  /// A "modal" for bar purposes = an imperatively pushed (pageless)
  /// ModalRoute: sheets, dialogs, popups, full-screen detail pushes.
  /// Anything owned by go_router carries `settings is Page` — that's
  /// NAVIGATION, never a modal, regardless of its momentary stack position.
  bool _isModal(Route<dynamic> route) =>
      route is ModalRoute && route.settings is! Page;

  void _sync() {
    _setVisible(_modals.isEmpty);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_isModal(route)) {
      _modals.add(route);
      _sync();
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_modals.remove(route)) _sync();
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (_modals.remove(route)) _sync();
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    var changed = false;
    if (oldRoute != null) changed = _modals.remove(oldRoute) || changed;
    if (newRoute != null && _isModal(newRoute)) {
      changed = _modals.add(newRoute) || changed;
    }
    if (changed) _sync();
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
