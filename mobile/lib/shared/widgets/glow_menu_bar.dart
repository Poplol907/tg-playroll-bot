import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';
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

  const GlowMenuBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _GlowBarBody(
        items: items,
        currentIndex: currentIndex,
        onTap: onTap,
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

  const _GlowBarBody({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = NebulaSurfaceProfile.nav.resolve(context);
    final isAdminPair = items.length == 2 &&
        items.first.icon == Icons.shield_outlined &&
        items.last.icon == Icons.settings_outlined;

    // Active colour drives the nav-wide ambient bloom.
    final activeColor = currentIndex < items.length
        ? items[currentIndex].glowColor
        : Colors.transparent;

    // Count fixed-width tabs so the fraction stays accurate.
    final tabCount = items.length;
    final activeFrac = isAdminPair
        ? (currentIndex == 0 ? 0.5 : 0.9)
        : (tabCount > 0 ? (currentIndex + 0.5) / tabCount : 0.5);

    return Container(
      key: const ValueKey('glow-menu-bar-surface'),
      decoration: BoxDecoration(
        color: surface.fill,
        gradient: surface.sheen,
        border: Border(
          top: BorderSide(
            color: surface.border,
            width: surface.borderWidth,
          ),
        ),
      ),
      child: Stack(
        children: [
          // ── Nav-wide ambient bloom ──────────────────────────────────
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

          // ── Tab row ─────────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NebulaTokens.sp8,
                vertical: NebulaTokens.sp8,
              ),
              child: isAdminPair
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        const tabWidth = 76.0;
                        final centerLeft =
                            constraints.maxWidth / 2 - tabWidth / 2;
                        return SizedBox(
                          height: 58,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                left: centerLeft,
                                width: tabWidth,
                                top: 0,
                                bottom: 0,
                                child: _GlowNavTab(
                                  item: items[0],
                                  selected: currentIndex == 0,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    onTap(0);
                                  },
                                ),
                              ),
                              Positioned(
                                right: 0,
                                width: tabWidth,
                                top: 0,
                                bottom: 0,
                                child: _GlowNavTab(
                                  item: items[1],
                                  selected: currentIndex == 1,
                                  isDark: isDark,
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    onTap(1);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...items.asMap().entries.map(
                              (e) => SizedBox(
                                width: 76,
                                child: _GlowNavTab(
                                  item: e.value,
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
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single animated tab — 3D flip + scaling radial glow
// ─────────────────────────────────────────────────────────────────────────────

class _GlowNavTab extends StatelessWidget {
  final GlowMenuItem item;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  const _GlowNavTab({
    required this.item,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _GlowTab(
        item: item,
        selected: selected,
        isDark: isDark,
        onTap: onTap,
      ),
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

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          item.icon,
          color: color,
          size: active ? 23.0 : 22.0,
          shadows: (active && isDark)
              ? [
                  Shadow(
                    color: item.glowColor.withValues(alpha: 0.55),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          item.label,
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 9,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: color,
            letterSpacing: 0.6,
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

    // In light mode use a near-black ring so it reads against the white bar.
    final ringColor = isDark ? color : const Color(0xFF111827);

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          ringColor.withValues(alpha: isDark ? 0.22 : 0.20),
          ringColor.withValues(alpha: isDark ? 0.09 : 0.07),
          Colors.transparent,
        ],
        stops: const [0.0, 0.48, 1.0],
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
