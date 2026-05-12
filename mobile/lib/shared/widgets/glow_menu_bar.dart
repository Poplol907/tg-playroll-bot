import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_visual_mode.dart';
import '../../core/theme/nebula_colors.dart';
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
//  • BackdropFilter at bar level for frosted-glass effect
// ─────────────────────────────────────────────────────────────────────────────

class GlowMenuBar extends StatelessWidget {
  final List<GlowMenuItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onThemeTap;
  final AppVisualMode? visualMode;

  const GlowMenuBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onSettingsTap,
    this.onThemeTap,
    this.visualMode,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: _GlowBarBody(
        items: items,
        currentIndex: currentIndex,
        onTap: onTap,
        onSettingsTap: onSettingsTap,
        onThemeTap: onThemeTap,
        visualMode: visualMode,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bar body — frosted-glass container + nav-wide ambient glow
// ─────────────────────────────────────────────────────────────────────────────

class _GlowBarBody extends StatelessWidget {
  final List<GlowMenuItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onThemeTap;
  final AppVisualMode? visualMode;

  const _GlowBarBody({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.onSettingsTap,
    this.onThemeTap,
    this.visualMode,
  });

  static IconData _modeIcon(AppVisualMode? mode) => switch (mode) {
        AppVisualMode.lightShader || AppVisualMode.lightLite =>
          Icons.light_mode_rounded,
        _ => Icons.dark_mode_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSettings = onSettingsTap != null;
    final hasTheme    = onThemeTap != null;

    // Active colour drives the nav-wide ambient bloom.
    final activeColor = currentIndex < items.length
        ? items[currentIndex].glowColor
        : Colors.transparent;

    // Count fixed-width extras so the fraction stays accurate.
    final extrasCount = (hasSettings ? 1 : 0) + (hasTheme ? 1 : 0);
    final totalSlots  = items.length + extrasCount * 0.55; // extras narrower
    final activeFrac  = items.isNotEmpty
        ? (currentIndex + 0.5) / totalSlots
        : 0.5;

    return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      NebulaColors.nebulaSurface,
                      NebulaColors.denseNebulaSurface,
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.82),
                      Colors.white.withValues(alpha: 0.96),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? NebulaColors.surfaceBorder
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
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
                  child: Row(
                    children: [
                      ...items.asMap().entries.map(
                            (e) => Expanded(
                              child: RepaintBoundary(
                                child: _GlowTab(
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
                          ),
                      if (hasSettings)
                        RepaintBoundary(
                          child: _GlowSettingsTab(
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onSettingsTap!();
                            },
                          ),
                        ),
                      if (hasTheme)
                        RepaintBoundary(
                          child: _GlowThemeTab(
                            icon: _modeIcon(visualMode),
                            isDark: isDark,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onThemeTap!();
                            },
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
                // Visible when inactive. Folds downward on selection.
                // Pivot = bottom-centre (Alignment.bottomCenter).
                Transform(
                  transform: Matrix4.identity()
                    ..rotateX(-math.pi / 2 * tRaw),
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
                // Starts at rotateX=90° (above, invisible).
                // Folds in from the top on selection.
                // Pivot = top-centre (Alignment.topCenter).
                Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
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
    final inactiveColor = isDark
        ? NebulaColors.ghostText
        : Colors.black.withValues(alpha: 0.55);
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
          item.label.toUpperCase(),
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
//  Settings tab — static, no flip
// ─────────────────────────────────────────────────────────────────────────────

class _GlowSettingsTab extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _GlowSettingsTab({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? NebulaColors.ghostText
        : Colors.black.withValues(alpha: 0.30);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.settings_ethernet_rounded, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              'СЕТ',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Theme toggle tab — static, no flip
// ─────────────────────────────────────────────────────────────────────────────

class _GlowThemeTab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;

  const _GlowThemeTab({
    required this.icon,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDark
        ? NebulaColors.ghostText
        : Colors.black.withValues(alpha: 0.30);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 48,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 3),
            Text(
              'ТЕМА',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 9,
                color: color,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
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
      old.color != color ||
      old.xFraction != xFraction ||
      old.isDark != isDark;
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
