import 'package:flutter/material.dart';
import '../../core/theme/nebula_tokens.dart';
import 'app_chrome_metrics.dart';

/// Shared insets for screens that sit inside AppShell.
///
/// The shell owns the iOS status/Dynamic Island area with the month bar and the
/// bottom navigation bar with its own SafeArea. Scrollables still need a little
/// breathing room plus keyboard inset so focused controls are never pinned under
/// the keyboard.
abstract class AppSafeInsets {
  static EdgeInsets screen(
    BuildContext context, {
    double left = NebulaTokens.sp20,
    double top = NebulaTokens.sp20,
    double right = NebulaTokens.sp20,
    double bottom = NebulaTokens.sp24,
    bool includeKeyboard = false,
    bool includeFloatingNavBar = true,
    bool includeFloatingTopBar = true,
  }) {
    final media = MediaQuery.of(context);
    // The shell's SafeArea(top:true) already consumes the Dynamic Island
    // inset before the screen builds, so we only add the floating top bar
    // here — never the status-bar viewPadding again, or it stacks twice.
    return EdgeInsets.fromLTRB(
      left,
      top +
          (includeFloatingTopBar
              ? AppChromeMetrics.routeContentTopReservation
              : 0),
      right,
      bottom +
          media.viewPadding.bottom +
          (includeFloatingNavBar
              ? AppChromeMetrics.floatingBottomNavReservation
              : 0) +
          (includeKeyboard ? media.viewInsets.bottom : 0),
    );
  }

  static EdgeInsets list(
    BuildContext context, {
    double left = NebulaTokens.sp16,
    double top = NebulaTokens.sp8,
    double right = NebulaTokens.sp16,
    double bottom = NebulaTokens.sp24,
    bool includeKeyboard = false,
    bool includeFloatingNavBar = true,
    bool includeFloatingTopBar = true,
  }) {
    return screen(
      context,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      includeKeyboard: includeKeyboard,
      includeFloatingNavBar: includeFloatingNavBar,
      includeFloatingTopBar: includeFloatingTopBar,
    );
  }

  static EdgeInsets modal(
    BuildContext context, {
    double left = NebulaTokens.sp20,
    double top = NebulaTokens.sp20,
    double right = NebulaTokens.sp20,
    double bottom = NebulaTokens.sp20,
  }) {
    final media = MediaQuery.of(context);
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom + media.viewPadding.bottom + media.viewInsets.bottom,
    );
  }
}

/// Canonical edge treatment for every scroll viewport: instead of a hard
/// rectangular clip, content dissolves softly at the top/bottom edge — text
/// "мылится" out of view rather than being guillotined by the window.
/// One mechanism for the whole app (PRIME RULE); applied by AppScrollView
/// and AppListView so every screen scrolls the same way.
class ScrollEdgeFade extends StatelessWidget {
  final Widget child;
  final double topFadeExtent;
  final double bottomFadeExtent;

  const ScrollEdgeFade({
    super.key,
    required this.child,
    this.topFadeExtent = 32,
    this.bottomFadeExtent = 32,
  });

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        final height = rect.height <= 0 ? 1.0 : rect.height;
        final topStop = (topFadeExtent / height).clamp(0.0, 0.45);
        final bottomStop = (1 - (bottomFadeExtent / height)).clamp(0.55, 1.0);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, topStop, bottomStop, 1],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }
}

class AppCustomScrollView extends StatelessWidget {
  final Widget header;
  final List<Widget> slivers;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool includeKeyboardInset;

  const AppCustomScrollView({
    super.key,
    required this.header,
    required this.slivers,
    this.padding,
    this.controller,
    this.physics,
    this.includeKeyboardInset = false,
  });

  @override
  Widget build(BuildContext context) {
    final insets = (padding ??
            AppSafeInsets.screen(
              context,
              includeKeyboard: includeKeyboardInset,
            ))
        .resolve(Directionality.of(context));

    return ScrollEdgeFade(
      child: CustomScrollView(
        key: const ValueKey('app-custom-scroll-view'),
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: physics ??
            const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              insets.left,
              insets.top,
              insets.right,
              0,
            ),
            sliver: SliverToBoxAdapter(child: header),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: NebulaTokens.sp20),
          ),
          ...slivers.map(
            (sliver) => SliverPadding(
              padding: EdgeInsets.only(
                left: insets.left,
                right: insets.right,
              ),
              sliver: sliver,
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: insets.bottom)),
        ],
      ),
    );
  }
}

class AppScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool includeKeyboardInset;

  const AppScrollView({
    super.key,
    required this.child,
    this.padding,
    this.controller,
    this.physics,
    this.includeKeyboardInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollEdgeFade(
      child: SingleChildScrollView(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: physics ??
            const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
        padding: padding ??
            AppSafeInsets.screen(context,
                includeKeyboard: includeKeyboardInset),
        child: child,
      ),
    );
  }
}

class AppListView extends StatelessWidget {
  final int itemCount;
  final NullableIndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool includeKeyboardInset;

  const AppListView.builder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.controller,
    this.physics,
    this.includeKeyboardInset = false,
  });

  @override
  Widget build(BuildContext context) {
    return ScrollEdgeFade(
      child: ListView.builder(
        controller: controller,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: physics,
        padding: padding ??
            AppSafeInsets.list(context, includeKeyboard: includeKeyboardInset),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}
