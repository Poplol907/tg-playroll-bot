import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_surface_profile.dart';
import '../../core/theme/nebula_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GlowMenuBar — reference-accurate port of v0 Glow Menu Component
//
//  Visual mechanics (1:1 with reference):
//  • Nav-wide ambient radial bloom centred on the active tab
//  • Per-item circular radial glow that SCALES 0.8 → 2.0 on selection
//  • Per-item 3D flip: front face folds down (rotateX 0→-90°),
//    back face folds in from above (rotateX 90°→0) — spring feel
//  • Theme-adaptive: dark = BlendMode.plus (additive neon glow)
//                    light = BlendMode.srcOver (soft colour tint)
//
//  Performance:
//  • RepaintBoundary per tab — isolated raster layers
//  • Glow via CustomPainter — one drawCircle call, zero BoxShadow overhead
//  • AnimationController per tab with spring-bezier curve
//  • No bar-level BackdropFilter; the surface uses a lightweight tint gradient
// ─────────────────────────────────────────────────────────────────────────────

class GlowMenuBar extends StatelessWidget {
  final List<GlowMenuItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;
  final GestureDragCancelCallback? onHorizontalDragCancel;

  /// Live fractional position of the nav-bar swipe (e.g. 1.3 = between tab 1
  /// and 2, leaning toward 1). Drives the macOS-dock proximity magnification:
  /// the tab the finger is sliding toward grows and brightens by distance.
  /// Null = no dock effect (desktop / no PageView).
  final ValueListenable<double>? magnify;

  /// True while the user is dragging the pill. The capsule scales up like a
  /// magnifier ("loupe") so it reads as a grabbable handle.
  final ValueListenable<bool>? dragActive;

  const GlowMenuBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.magnify,
    this.dragActive,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _GlowBarBody(
        items: items,
        currentIndex: currentIndex,
        onTap: onTap,
        magnify: magnify,
        dragActive: dragActive,
        onHorizontalDragStart: onHorizontalDragStart,
        onHorizontalDragUpdate: onHorizontalDragUpdate,
        onHorizontalDragEnd: onHorizontalDragEnd,
        onHorizontalDragCancel: onHorizontalDragCancel,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bar body — profile-driven nav surface + nav-wide ambient glow
// ─────────────────────────────────────────────────────────────────────────────

class _GlowBarBody extends StatelessWidget {
  final List<GlowMenuItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final ValueListenable<double>? magnify;
  final ValueListenable<bool>? dragActive;
  final GestureDragStartCallback? onHorizontalDragStart;
  final GestureDragUpdateCallback? onHorizontalDragUpdate;
  final GestureDragEndCallback? onHorizontalDragEnd;
  final GestureDragCancelCallback? onHorizontalDragCancel;

  const _GlowBarBody({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.magnify,
    this.dragActive,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = NebulaSurfaceProfile.nav.resolve(context);

    // Active colour drives the nav-wide ambient bloom.
    final activeColor = currentIndex < items.length
        ? items[currentIndex].glowColor
        : Colors.transparent;

    // Count fixed-width tabs so the fraction stays accurate.
    final tabCount = items.length;
    final activeFrac = tabCount > 0 ? (currentIndex + 0.5) / tabCount : 0.5;

    // Floating oval island: one stadium-shaped glass capsule holding every
    // tab, lifted off the screen edge. The area around the pill stays
    // transparent so the app background flows beneath it.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    // The island contracts (and its sheen/glow fade) while the pill is
    // grabbed, so the loupe-grown capsule looks like it has *consumed* the
    // bar — same illusion as iOS / Telegram where the active handle
    // dominates the bar during a drag.
    final dragNotifier = dragActive;
    final island = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: onHorizontalDragStart,
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      onHorizontalDragEnd: onHorizontalDragEnd,
      onHorizontalDragCancel: onHorizontalDragCancel,
      child: _BarIsland(
        dragActive: dragNotifier,
        child: Container(
          key: const ValueKey('glow-menu-bar-surface'),
          decoration: BoxDecoration(
            color: surface.fill,
            borderRadius: NebulaRadii.pillBorder,
            border: Border.all(
              color: surface.border,
              width: surface.borderWidth,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: NebulaAlpha.border),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    // Soft diffused lift on white — wide blur, low alpha.
                    BoxShadow(
                      color: Colors.black.withValues(alpha: NebulaAlpha.mist),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          // Outer Stack lets the pill draw OVER the ClipRRect — when the
          // loupe scales the capsule to 1.18×, it can bulge past the bar's
          // stadium edge instead of being clipped to a pill-shaped tube.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: NebulaRadii.pillBorder,
                child: Stack(
                  children: [
                    // ── Matte sheen over the fill ─────────────────────────
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(gradient: surface.sheen),
                        ),
                      ),
                    ),

                    // ── Nav-wide ambient bloom ────────────────────────────
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _NavAmbientPainter(
                            color: activeColor,
                            xFraction: activeFrac,
                            isDark: isDark,
                          ),
                        ),
                      ),
                    ),

                    // ── Tab row ───────────────────────────────────────────
                    // Horizontal padding = 0: the edge tabs (and their
                    // pills) flush against the bar's stadium edge, so the
                    // capsule reads as a real segment of the bar. Vertical
                    // padding stays to keep the icons from hitting the
                    // top/bottom kant — pill is the background, icons get
                    // breathing room inside it.
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: NebulaTokens.sp8,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ...items.asMap().entries.map(
                                (e) => Expanded(
                                  child: _GlowNavTab(
                                    item: e.value,
                                    index: e.key,
                                    magnify: magnify,
                                    selected: e.key == currentIndex,
                                    isDark: isDark,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      onTap(e.key);
                                    },
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Liquid pill — OUTSIDE the ClipRRect so the loupe-scale
              //    (1.18×) bulges past the bar's stadium edge instead of
              //    being clipped to a pill-shaped tube. Sits as a top
              //    overlay in the outer Stack, still IgnorePointer so it
              //    doesn't intercept tab taps.
              if (magnify != null && items.length > 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: _LiquidPill(
                      magnify: magnify!,
                      dragActive: dragActive,
                      items: items,
                      isDark: isDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 16, bottomInset + 10),
      child: island,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _BarIsland — passthrough wrapper. The bar stays geometrically stable
//  whether the user is idle or dragging; only the pill inside reacts to the
//  drag (loupe scale). Bar + pill are concentric parts of one mechanism, so
//  resizing the bar would break the visual coupling.
// ─────────────────────────────────────────────────────────────────────────────

class _BarIsland extends StatelessWidget {
  final ValueListenable<bool>? dragActive;
  final Widget child;

  const _BarIsland({required this.dragActive, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single animated tab — 3D flip + scaling radial glow
// ─────────────────────────────────────────────────────────────────────────────

class _GlowNavTab extends StatelessWidget {
  final GlowMenuItem item;
  final int index;
  final ValueListenable<double>? magnify;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _GlowNavTab({
    required this.item,
    required this.index,
    required this.magnify,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tab = RepaintBoundary(
      child: _GlowTab(
        item: item,
        selected: selected,
        isDark: isDark,
        onTap: onTap,
      ),
    );
    if (magnify == null) return tab;
    // Dock proximity: scale this tab by how close the swipe position is to it.
    // t = max(0, 1 - dist/range); scale = 1 + t*peak. Same shape as the macOS
    // dock magnification, driven by the live PageView offset instead of a cursor.
    return ValueListenableBuilder<double>(
      valueListenable: magnify!,
      builder: (_, pos, child) {
        const range = 1.35; // how many tabs away still react
        const peak = 0.26; // extra scale at the focal tab
        final dist = (index - pos).abs();
        final t = (1.0 - dist / range).clamp(0.0, 1.0);
        final scale = 1.0 + t * peak;
        return Transform.scale(
          scale: scale,
          filterQuality: FilterQuality.low,
          child: child,
        );
      },
      child: tab,
    );
  }
}

class _GlowTab extends StatefulWidget {
  final GlowMenuItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _GlowTab({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_GlowTab> createState() => _GlowTabState();
}

class _GlowTabState extends State<_GlowTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Smooth ease-out — matches framer-motion spring(stiffness:100, damping:20),
  // which is critically damped (no overshoot). The flip unfolds like cloth,
  // not a spring — gentle and airy, matching the reference.
  static const _springFwd = Cubic(0.22, 1.0, 0.36, 1.0); // ease-out-expo
  static const _springRev = Cubic(0.64, 0.0, 0.78, 0.0);

  late final Animation<double> _spring;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
      value: widget.selected ? 1.0 : 0.0,
    );
    _spring = CurvedAnimation(
      parent: _ctrl,
      curve: _springFwd,
      reverseCurve: _springRev,
    );
  }

  @override
  void didUpdateWidget(_GlowTab old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      widget.selected ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 58,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            // tRaw: spring curve, may overshoot — good for 3D rotation.
            final tRaw = _spring.value;
            // t: linear 0→1, clamped — used for opacity and scale.
            final t = _ctrl.value.clamp(0.0, 1.0);

            return Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // ── Circular scaling glow ──────────────────────────────────
                // Scale: 0.8 (inactive) → 2.0 (active) — matches reference.
                if (t > 0.01)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.8 + t * 1.2,
                      child: Opacity(
                        opacity: (t * 0.85).clamp(0.0, 1.0),
                        child: CustomPaint(
                          painter: _RadialGlowPainter(
                            color: widget.item.glowColor,
                            isDark: widget.isDark,
                          ),
                        ),
                      ),
                    ),
                  ),

                // ── Front face ─────────────────────────────────────────────
                // Excluded from tree once fully active (t≥0.99) — keeps
                // find.text() returning findsOneWidget in tests.
                if (t < 0.99)
                  Transform(
                    transform: Matrix4.identity()..rotateX(-math.pi / 2 * tRaw),
                    alignment: Alignment.bottomCenter,
                    child: Opacity(
                      opacity: (1.0 - t * 1.6).clamp(0.0, 1.0),
                      child: _TabContent(
                        item: widget.item,
                        active: false,
                        isDark: widget.isDark,
                      ),
                    ),
                  ),

                // ── Back face ──────────────────────────────────────────────
                // Only added to tree when visible (t>0.01).
                if (t > 0.01)
                  Transform(
                    transform: Matrix4.identity()
                      ..rotateX(math.pi / 2 * (1.0 - tRaw)),
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: ((t - 0.25) * 1.6).clamp(0.0, 1.0),
                      child: _TabContent(
                        item: widget.item,
                        active: true,
                        isDark: widget.isDark,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tab visual content — icon + label, reused for both flip faces
// ─────────────────────────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  final GlowMenuItem item;
  final bool active;
  final bool isDark;

  const _TabContent({
    required this.item,
    required this.active,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final inactiveColor = isDark ? NebulaColors.ghostText : tokens.mutedText;
    final color = active ? item.glowColor : inactiveColor;

    // Constant icon size + constant label weight: active state changes COLOR
    // and adds glow, never geometry. This keeps every tab on the same icon
    // baseline and text baseline — no jiggle when the pill arrives, all
    // labels aligned, all icons the same size across the bar.
    const double iconSize = 20.0;
    const double labelSize = 8.0;
    const FontWeight labelWeight = FontWeight.w600;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.icon,
          color: color,
          size: iconSize,
          shadows: active
              ? (isDark
                  ? [
                      Shadow(
                        color: item.glowColor.withValues(alpha: 0.55),
                        blurRadius: 14,
                      ),
                    ]
                  // Light: soft scattered light — wide blur, low alpha, so
                  // the icon glows gently instead of casting a hard halo.
                  : [
                      Shadow(
                        color: item.glowColor
                            .withValues(alpha: NebulaAlpha.accent),
                        blurRadius: 10,
                      ),
                      Shadow(
                        color: item.glowColor
                            .withValues(alpha: NebulaAlpha.subtle),
                        blurRadius: 22,
                      ),
                    ])
              : null,
        ),
        const SizedBox(height: 4),
        // FittedBox scales the label DOWN if it would otherwise overflow the
        // tab cell — so "Календарь" (longest label) shrinks to fit instead of
        // hard-clipping. Centred horizontally so shorter labels stay centred
        // and longer ones simply read a hair smaller.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.center,
          child: Text(
            item.label,
            maxLines: 1,
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: labelSize,
              fontWeight: labelWeight,
              color: color,
              letterSpacing: 0.3,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Per-item radial glow — CIRCLE (was oval before — that was the "кривое" bug)
//
//  Old code used drawOval(width: radius*2, height: radius) — half height of
//  width → flat squashed ellipse, looked wrong. Now: drawCircle using the
//  shorter dimension so it's always a perfect circle regardless of tab size.
// ─────────────────────────────────────────────────────────────────────────────

class _RadialGlowPainter extends CustomPainter {
  final Color color;
  final bool isDark;

  const _RadialGlowPainter({required this.color, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.72;

    // Light mode: the tab's own accent as soft scattered light (wider falloff,
    // lower alpha) — diffused colour instead of a hard near-black puck.
    final ringColor = color;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          ringColor.withValues(alpha: isDark ? 0.22 : 0.14),
          ringColor.withValues(alpha: isDark ? 0.09 : 0.05),
          Colors.transparent,
        ],
        stops: isDark ? const [0.0, 0.48, 1.0] : const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RadialGlowPainter old) =>
      old.color != color || old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Nav-wide ambient glow — soft bloom that tracks the active tab
// ─────────────────────────────────────────────────────────────────────────────

class _NavAmbientPainter extends CustomPainter {
  final Color color;
  final double xFraction; // 0.0–1.0 horizontal centre of the active tab
  final bool isDark;

  const _NavAmbientPainter({
    required this.color,
    required this.xFraction,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (color == Colors.transparent) return;

    final cx = size.width * xFraction;
    // Bloom originates at the very top edge and bleeds downward.
    const cy = 0.0;
    final rx = size.width * 0.38;
    final ry = size.height * 0.90;

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: isDark ? 0.20 : 0.11),
          color.withValues(alpha: isDark ? 0.07 : 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: rx * 2,
          height: ry * 2,
        ),
      )
      ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver;

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx * 2,
        height: ry * 2,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(_NavAmbientPainter old) =>
      old.color != color || old.xFraction != xFraction || old.isDark != isDark;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Liquid pill — stadium-shaped capsule that glides under the active tab
//
//  Reads the live fractional swipe position (`magnify`) and renders a single
//  rounded-rect "pill" centred on that fractional tab. As the user drags
//  between sections, the pill slides smoothly — just like the floating
//  capsule under iOS 26 / Instagram tab bars.
//
//  Colours interpolate between the surrounding tabs' glow colours so the
//  pill takes on the new section's hue as it arrives.
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidPill extends StatelessWidget {
  final ValueListenable<double> magnify;
  final ValueListenable<bool>? dragActive;
  final List<GlowMenuItem> items;
  final bool isDark;

  const _LiquidPill({
    required this.magnify,
    required this.dragActive,
    required this.items,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: magnify,
      builder: (_, pos, __) {
        return LayoutBuilder(
          builder: (_, constraints) {
            final n = items.length;
            if (n == 0) return const SizedBox.shrink();

            // Pill lies ON the bar — a separate object resting on the
            // surface, not a carved-out segment of it. Equal `pillInset`
            // gap on all four sides makes the bar's stadium outline
            // visible around every pill position, so the eye reads pill
            // and bar as two layers (loupe over glass), not one shape.
            const pillInset = 4.0;
            final innerWidth = constraints.maxWidth;
            final tabWidth = innerWidth / n;
            final pillWidth = tabWidth - pillInset * 2;
            const pillTop = pillInset;
            const pillBottom = pillInset;

            // Hue interpolates between the two neighbouring tabs so the
            // capsule takes on the new section's colour as the swipe lands.
            final lower = pos.floor().clamp(0, n - 1);
            final upper = pos.ceil().clamp(0, n - 1);
            final frac = (pos - lower).clamp(0.0, 1.0);
            final color = Color.lerp(
              items[lower].glowColor,
              items[upper].glowColor,
              frac,
            )!;

            final left = pos * tabWidth + pillInset;

            return _LoupePill(
              dragActive: dragActive,
              left: left,
              top: pillTop,
              bottom: pillBottom,
              width: pillWidth,
              color: color,
              isDark: isDark,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LoupePill — the concentric capsule. Idle: sits inside the bar with an
//  equal `pillInset` gap on every side, so its stadium outline runs parallel
//  to the bar's outline (kant ∥ kant). When the user grabs it, only the pill
//  scales up (×1.18, easeOutCubic) — it bulges past the bar's edge like a
//  glass loupe held over the surface. The bar itself is geometrically still:
//  pill is the part that "magnifies", bar is the stable host.
// ─────────────────────────────────────────────────────────────────────────────

class _LoupePill extends StatelessWidget {
  final ValueListenable<bool>? dragActive;
  final double left;
  final double top;
  final double bottom;
  final double width;
  final Color color;
  final bool isDark;

  const _LoupePill({
    required this.dragActive,
    required this.left,
    required this.top,
    required this.bottom,
    required this.width,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final notifier = dragActive;
    final placed = Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          bottom: bottom,
          width: width,
          child: _capsule(active: notifier?.value ?? false),
        ),
      ],
    );
    if (notifier == null) return placed;
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (_, active, __) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              width: width,
              child: AnimatedScale(
                // Loupe: only the capsule grows. The outer Stack in
                // _GlowBarBody has clipBehavior:none, so this scale-up
                // bulges PAST the bar's stadium edge instead of being
                // clipped to it — reads as a magnifier hovering over
                // the surface, not a fill that takes over the bar.
                scale: active ? 1.18 : 1.0,
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: _capsule(active: active),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _capsule({required bool active}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: NebulaRadii.pillBorder,
        color: color.withValues(
          alpha: isDark
              ? (active ? NebulaAlpha.border : NebulaAlpha.subtle)
              : (active ? NebulaAlpha.subtle : NebulaAlpha.surface),
        ),
        border: Border.all(
          color: color.withValues(
            alpha: isDark
                ? (active ? NebulaAlpha.medium : NebulaAlpha.border)
                : (active ? NebulaAlpha.strong : NebulaAlpha.accent),
          ),
          width: active ? 1.2 : 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(
              alpha: isDark
                  ? (active ? NebulaAlpha.border : NebulaAlpha.surface)
                  : (active ? NebulaAlpha.accent : NebulaAlpha.mist),
            ),
            blurRadius: active ? 24 : 12,
            spreadRadius: active ? 1.5 : -1,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data model
// ─────────────────────────────────────────────────────────────────────────────

class GlowMenuItem {
  final IconData icon;
  final String label;
  final Color glowColor;

  const GlowMenuItem({
    required this.icon,
    required this.label,
    required this.glowColor,
  });
}
