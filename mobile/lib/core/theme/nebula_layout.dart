import 'dart:ui';

import 'package:flutter/material.dart';

/// Layout tokens — single source of truth for **shape-and-size** parameters
/// that change between platforms.
///
/// Why this exists separately from `NebulaTokens` (spacing, radii, motion):
///
/// - `NebulaTokens` are universal primitives (an 8px grid does not depend
///   on the platform). They never change at runtime.
/// - `NebulaLayout` is a **resolved policy**: how wide should the sidebar
///   be on macOS? Should desktop content max out at 1200px? Should card
///   density be compact on phone? These vary per platform.
///
/// SOLID notes:
/// - **DIP**: `AppShell`, `DesktopSidebar`, `DesktopContentFrame` read
///   `NebulaLayout.of(context).<token>` instead of hardcoding `width: 72`
///   or `maxWidth: 1200`. Widgets depend on the abstraction.
/// - **OCP**: a new platform (tablet, foldable) means adding another
///   `NebulaLayout.tablet` factory; widgets don't change.
/// - **SRP**: layout doesn't know about colors or fonts. Profiles don't
///   know about widths. Each axis is in exactly one file.
class NebulaLayout extends ThemeExtension<NebulaLayout> {
  /// Width of the persistent left sidebar on desktop. On mobile this is
  /// 0 because there is no sidebar (bottom nav instead).
  final double sidebarWidth;

  /// Height of the top header / month bar.
  final double headerHeight;

  /// Maximum width of the content column inside the shell. Beyond this
  /// the layout adds horizontal padding — never let lines of body text
  /// stretch across 4K screens.
  final double contentMaxWidth;

  /// Width of action buttons on bottom-of-modal action rows.
  final double primaryButtonMinHeight;

  /// Minimum tap target. Mobile = 44 (Apple HIG). Desktop can be 36.
  final double tapTargetMin;

  /// Horizontal screen padding (page gutter). Mobile is tighter than desktop.
  final double pageGutter;

  /// Card density — small / medium / large extra padding inside list cards.
  /// Mobile = compact, desktop = roomy. One token controls a hundred surfaces.
  final EdgeInsetsGeometry listCardPadding;

  /// Modal width on desktop (dialog form-factor). Ignored on mobile where
  /// modals are bottom sheets.
  final double desktopModalWidth;

  /// Whether the current platform should prefer dialogs over bottom sheets.
  /// `AdaptiveModal` uses this to pick its host.
  final bool prefersDialogs;

  const NebulaLayout({
    required this.sidebarWidth,
    required this.headerHeight,
    required this.contentMaxWidth,
    required this.primaryButtonMinHeight,
    required this.tapTargetMin,
    required this.pageGutter,
    required this.listCardPadding,
    required this.desktopModalWidth,
    required this.prefersDialogs,
  });

  /// Mobile preset — tight gutters, no sidebar, sheets over dialogs.
  static const NebulaLayout mobile = NebulaLayout(
    sidebarWidth: 0,
    headerHeight: 52,
    contentMaxWidth: double.infinity,
    primaryButtonMinHeight: 48,
    tapTargetMin: 44,
    pageGutter: 16,
    listCardPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    desktopModalWidth: 0,
    prefersDialogs: false,
  );

  /// Desktop preset — generous breathing room, sidebar, dialogs.
  static const NebulaLayout desktop = NebulaLayout(
    sidebarWidth: 72,
    headerHeight: 56,
    contentMaxWidth: 1200,
    primaryButtonMinHeight: 44,
    tapTargetMin: 36,
    pageGutter: 24,
    listCardPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    desktopModalWidth: 480,
    prefersDialogs: true,
  );

  /// Convenience accessor — falls back to mobile if no extension is registered.
  static NebulaLayout of(BuildContext context) =>
      Theme.of(context).extension<NebulaLayout>() ?? mobile;

  @override
  NebulaLayout copyWith({
    double? sidebarWidth,
    double? headerHeight,
    double? contentMaxWidth,
    double? primaryButtonMinHeight,
    double? tapTargetMin,
    double? pageGutter,
    EdgeInsetsGeometry? listCardPadding,
    double? desktopModalWidth,
    bool? prefersDialogs,
  }) {
    return NebulaLayout(
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      headerHeight: headerHeight ?? this.headerHeight,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      primaryButtonMinHeight:
          primaryButtonMinHeight ?? this.primaryButtonMinHeight,
      tapTargetMin: tapTargetMin ?? this.tapTargetMin,
      pageGutter: pageGutter ?? this.pageGutter,
      listCardPadding: listCardPadding ?? this.listCardPadding,
      desktopModalWidth: desktopModalWidth ?? this.desktopModalWidth,
      prefersDialogs: prefersDialogs ?? this.prefersDialogs,
    );
  }

  /// Some layout values may be `double.infinity` (e.g. mobile content
  /// width). `lerpDouble` rejects infinity, so snap such fields on the
  /// midpoint instead of interpolating them.
  static double _safeLerp(double a, double b, double t) {
    if (a.isInfinite || b.isInfinite) return t < 0.5 ? a : b;
    return lerpDouble(a, b, t)!;
  }

  @override
  NebulaLayout lerp(ThemeExtension<NebulaLayout>? other, double t) {
    if (other is! NebulaLayout) return this;
    return NebulaLayout(
      sidebarWidth: _safeLerp(sidebarWidth, other.sidebarWidth, t),
      headerHeight: _safeLerp(headerHeight, other.headerHeight, t),
      contentMaxWidth: _safeLerp(contentMaxWidth, other.contentMaxWidth, t),
      primaryButtonMinHeight:
          _safeLerp(primaryButtonMinHeight, other.primaryButtonMinHeight, t),
      tapTargetMin: _safeLerp(tapTargetMin, other.tapTargetMin, t),
      pageGutter: _safeLerp(pageGutter, other.pageGutter, t),
      listCardPadding:
          EdgeInsetsGeometry.lerp(listCardPadding, other.listCardPadding, t)!,
      desktopModalWidth:
          _safeLerp(desktopModalWidth, other.desktopModalWidth, t),
      prefersDialogs: t < 0.5 ? prefersDialogs : other.prefersDialogs,
    );
  }
}
