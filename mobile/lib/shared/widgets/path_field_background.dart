import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_tokens.dart';

class PathFieldBackground extends StatefulWidget {
  final Widget child;
  final CosmoThemeTokens tokens;
  final bool animated;

  const PathFieldBackground({
    super.key,
    required this.child,
    required this.tokens,
    this.animated = true,
  });

  @override
  State<PathFieldBackground> createState() => _PathFieldBackgroundState();
}

class _PathFieldBackgroundState extends State<PathFieldBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: NebulaTokens.ambientLoop * 2,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion || !widget.animated) {
      _controller
        ..stop()
        ..value = 0.72;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.tokens.background,
            widget.tokens.backgroundMid,
            widget.tokens.background,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _PathFieldPainter(
            progress: _controller,
            tokens: widget.tokens,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PathFieldPainter extends CustomPainter {
  static const _viewBox = Size(696, 316);

  // Specular glints gliding along the stripes — ambient, never interactive.
  // Tuned low so they read as light catching the glass, not as motion noise.
  static const double _glintHaloAlpha = 0.10;
  static const double _glintCoreAlpha = 0.22;
  static const double _glintLengthFrac = 0.085;

  final Animation<double> progress;
  final CosmoThemeTokens tokens;

  _PathFieldPainter({
    required this.progress,
    required this.tokens,
  }) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final t = progress.value;
    final scale =
        math.max(size.width / _viewBox.width, size.height / _viewBox.height);
    final dx = (size.width - _viewBox.width * scale) / 2;
    final dy = (size.height - _viewBox.height * scale) / 2;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale, scale);

    _paintPaths(canvas, position: 1, progress: t);
    _paintPaths(canvas, position: -1, progress: (t + 0.35) % 1.0);
    _paintGlints(canvas, position: 1, t: t);
    _paintGlints(canvas, position: -1, t: (t + 0.5) % 1.0);

    canvas.restore();
  }

  /// Soft accent glints that travel along a handful of stripes. Two passes:
  /// a blurred halo for diffusion + a thin brighter core. Integer speeds keep
  /// the loop seamless when the controller wraps.
  void _paintGlints(Canvas canvas, {required int position, required double t}) {
    final accent = tokens.focusAccent;
    for (var k = 0; k < 6; k++) {
      final i = 5 + k * 6; // which stripe carries this glint
      final speed = 1 + (k % 2);
      final phase = (t * speed + k * 0.1618) % 1.0;
      final path = _buildReferencePath(i, position);
      for (final metric in path.computeMetrics()) {
        final glintLen = metric.length * _glintLengthFrac;
        final start = metric.length * phase;
        final end = math.min(start + glintLen, metric.length);
        if (end - start < 1) continue;
        final seg = metric.extractPath(start, end);
        canvas.drawPath(
          seg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2.6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5)
            ..color = accent.withValues(alpha: _glintHaloAlpha),
        );
        canvas.drawPath(
          seg,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.0
            ..color = accent.withValues(alpha: _glintCoreAlpha),
        );
      }
    }
  }

  void _paintPaths(
    Canvas canvas, {
    required int position,
    required double progress,
  }) {
    final baseColor = tokens.primaryText;
    final accentColor = tokens.focusAccent;
    final reveal = Curves.easeOut.transform(progress.clamp(0.0, 1.0));

    for (var i = 0; i < 36; i++) {
      final path = _buildReferencePath(i, position);
      final metrics = path.computeMetrics().toList(growable: false);
      final opacityPulse = 0.55 + 0.45 * math.sin(progress * math.pi * 2 + i);
      final strokeOpacity = (0.018 + i * 0.0018) * opacityPulse;
      final color = Color.lerp(
        baseColor,
        accentColor,
        (i / 35) * 0.22,
      )!
          .withValues(alpha: strokeOpacity.clamp(0.012, 0.082));
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.55 + i * 0.025
        ..color = color;

      for (final metric in metrics) {
        final visibleLength = metric.length * (0.36 + reveal * 0.64);
        final offset = metric.length * progress * (position == 1 ? 1 : -1);
        final start = offset % metric.length;
        final end = (start + visibleLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        if (start + visibleLength > metric.length) {
          canvas.drawPath(
            metric.extractPath(0, start + visibleLength - metric.length),
            paint,
          );
        }
      }
    }
  }

  Path _buildReferencePath(int i, int position) {
    final xShift = (i * 5 * position).toDouble();
    final yShift = (i * 6).toDouble();

    return Path()
      ..moveTo(-380 + xShift, -189 - yShift)
      ..cubicTo(
        -380 + xShift,
        -189 - yShift,
        -312 + xShift,
        216 - yShift,
        152 + xShift,
        343 - yShift,
      )
      ..cubicTo(
        616 + xShift,
        470 - yShift,
        684 + xShift,
        875 - yShift,
        684 + xShift,
        875 - yShift,
      );
  }

  @override
  bool shouldRepaint(covariant _PathFieldPainter oldDelegate) {
    return oldDelegate.tokens != tokens;
  }
}
