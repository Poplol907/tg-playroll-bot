import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/nebula_colors.dart';

/// Touch glow overlay — renders ripples without rebuilding the widget tree.
///
/// Old approach: TweenAnimationBuilder + setState per touch → full tree rebuild.
/// New approach: single CustomPainter driven by one AnimationController.
///   - setState called only when glow list transitions empty↔non-empty (≤2x per touch)
///   - All glow animation happens inside the painter, zero widget rebuilds mid-animation
class GlobalTouchOverlay extends StatefulWidget {
  final Widget child;
  const GlobalTouchOverlay({super.key, required this.child});

  @override
  State<GlobalTouchOverlay> createState() => _GlobalTouchOverlayState();
}

class _GlowPoint {
  final Offset position;
  double age = 0.0; // 0 → 1 over lifetime

  _GlowPoint(this.position);
}

class _GlobalTouchOverlayState extends State<GlobalTouchOverlay>
    with TickerProviderStateMixin {

  final List<_GlowPoint> _glows = [];
  AnimationController?   _ctrl;

  static const double _duration = 0.55; // seconds per glow

  void _onPointerDown(PointerDownEvent event) {
    _glows.add(_GlowPoint(event.localPosition));
    _ensureRunning();
  }

  void _ensureRunning() {
    if (_ctrl != null) return;
    final ctrl = AnimationController(
      vsync: this,
      duration: const Duration(days: 1), // driven manually
    )..addListener(_onFrame);
    _ctrl = ctrl;
    if (mounted)  setState(() {});
    ctrl.forward();
  }

  void _onFrame() {
    const dt = 1 / 60.0;
    bool anyAlive = false;
    for (final g in _glows) {
      g.age += dt / _duration;
      if (g.age < 1.0) anyAlive = true;
    }
    _glows.removeWhere((g) => g.age >= 1.0);
    if (!anyAlive) _stop();
  }

  void _stop() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    _ctrl = null;
    ctrl.removeListener(_onFrame);
    ctrl.dispose();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onFrame);
    _ctrl?.dispose();
    _ctrl = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      behavior: HitTestBehavior.translucent,
      child: CustomPaint(
        // foregroundPainter draws on top of child — no Stack needed
        foregroundPainter: _ctrl != null
            ? _GlowPainter(glows: _glows, repaint: _ctrl!)
            : null,
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAINTER
// ─────────────────────────────────────────────

class _GlowPainter extends CustomPainter {
  final List<_GlowPoint> glows;

  _GlowPainter({required this.glows, required Listenable repaint})
      : super(repaint: repaint);

  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    for (final g in glows) {
      final t      = g.age.clamp(0.0, 1.0);
      final eased  = Curves.easeOutCirc.transform(t);
      final scale  = 0.5 + eased * 0.5;
      final opacity = pow(1.0 - t, 2).toDouble();
      final radius = 100.0 * scale;
      final center = g.position;

      _paint.shader = RadialGradient(
        colors: [
          NebulaColors.milkyGlow.withValues(alpha: 0.18 * opacity),
          NebulaColors.stellarBlue.withValues(alpha: 0.07 * opacity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, _paint);
    }
  }

  @override
  bool shouldRepaint(_GlowPainter old) => false; // repaint listenable handles it
}
