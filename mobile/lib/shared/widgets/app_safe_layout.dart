import 'package:flutter/material.dart';
import '../../core/theme/nebula_tokens.dart';

/// Shared insets for screens that sit inside AppShell.
///
/// The shell owns the iOS status/Dynamic Island area with the month bar and the
/// bottom navigation bar with its own SafeArea. Scrollables still need a little
/// breathing room plus keyboard inset so focused controls are never pinned under
/// the keyboard.
abstract class AppSafeInsets {
  /// Approximate height of the floating GlowMenuBar capsule + its bottom
  /// inset. Used to push scroll content above the floating bar so the last
  /// items aren't hidden behind the pill.
  static const double floatingNavBarHeight = 84.0;

  static EdgeInsets screen(
    BuildContext context, {
    double left = NebulaTokens.sp20,
    double top = NebulaTokens.sp20,
    double right = NebulaTokens.sp20,
    double bottom = NebulaTokens.sp24,
    bool includeKeyboard = false,
    bool includeFloatingNavBar = true,
  }) {
    final media = MediaQuery.of(context);
    return EdgeInsets.fromLTRB(
      left,
      top,
      right,
      bottom +
          media.viewPadding.bottom +
          (includeFloatingNavBar ? floatingNavBarHeight : 0) +
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
  }) {
    return screen(
      context,
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      includeKeyboard: includeKeyboard,
      includeFloatingNavBar: includeFloatingNavBar,
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

  const ScrollEdgeFade({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.04, 0.96, 1.0],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: child,
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
