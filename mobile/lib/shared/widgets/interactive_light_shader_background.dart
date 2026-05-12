import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/cosmo_theme_tokens.dart';

class InteractiveLightShaderBackground extends StatefulWidget {
  final Widget child;
  final CosmoThemeTokens tokens;
  final ValueChanged<int>? onDebugSplatCountChanged;

  const InteractiveLightShaderBackground({
    super.key,
    required this.child,
    required this.tokens,
    this.onDebugSplatCountChanged,
  });

  @override
  State<InteractiveLightShaderBackground> createState() =>
      _InteractiveLightShaderBackgroundState();
}

class _InteractiveLightShaderBackgroundState
    extends State<InteractiveLightShaderBackground>
    with SingleTickerProviderStateMixin {
  static const _lifetime = 0.9;
  static const _maxSplats = 10;
  static const _moveSplatDistance = 42.0;

  final List<_LightSplat> _splats = [];
  AnimationController? _controller;
  Offset? _lastPointer;
  Offset? _lastSplatPointer;
  int _lastReportedSplatCount = 0;
  Duration? _lastFrameElapsed;

  void _onPointerDown(PointerDownEvent event) {
    _lastPointer = event.localPosition;
    _lastSplatPointer = event.localPosition;
    _addSplat(event.localPosition, 1.0);
  }

  void _onPointerMove(PointerMoveEvent event) {
    final previous = _lastPointer ?? event.localPosition;
    final anchor = _lastSplatPointer ?? previous;
    final distanceFromLastSplat = (event.localPosition - anchor).distance;
    _lastPointer = event.localPosition;

    if (distanceFromLastSplat < _moveSplatDistance) return;

    final strength =
        (0.45 + distanceFromLastSplat / _moveSplatDistance).clamp(0.45, 1.35);
    _lastSplatPointer = event.localPosition;
    _addSplat(event.localPosition, strength);
  }

  void _onPointerUp(PointerUpEvent _) {
    _lastPointer = null;
    _lastSplatPointer = null;
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _lastPointer = null;
    _lastSplatPointer = null;
  }

  void _addSplat(Offset position, double strength) {
    _splats.add(_LightSplat(position: position, strength: strength));
    if (_splats.length > _maxSplats) {
      _splats.removeRange(0, _splats.length - _maxSplats);
    }
    _reportSplatCount();
    _ensureRunning();
  }

  void _ensureRunning() {
    if (_controller != null) return;

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onFrame);

    _lastFrameElapsed = Duration.zero;
    _controller = controller;
    if (mounted) setState(() {});
    controller.forward();
  }

  void _onFrame() {
    final elapsed = _controller?.lastElapsedDuration ?? Duration.zero;
    final previous = _lastFrameElapsed ?? elapsed;
    final dt =
        (elapsed - previous).inMicroseconds / Duration.microsecondsPerSecond;
    _lastFrameElapsed = elapsed;

    if (dt <= 0) return;

    for (final splat in _splats) {
      splat.age += dt / _lifetime;
    }
    _splats.removeWhere((splat) => splat.age >= 1);
    _reportSplatCount();

    if (_splats.isEmpty) {
      _stop();
    }
  }

  void _reportSplatCount() {
    if (_lastReportedSplatCount == _splats.length) return;
    _lastReportedSplatCount = _splats.length;
    widget.onDebugSplatCountChanged?.call(_splats.length);
  }

  void _stop() {
    final controller = _controller;
    if (controller == null) return;

    controller.removeListener(_onFrame);
    controller.dispose();
    _controller = null;
    _lastFrameElapsed = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onFrame);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return widget.child;
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: CustomPaint(
        painter: _controller == null
            ? null
            : _LightShaderPainter(
                splats: _splats,
                tokens: widget.tokens,
                repaint: _controller!,
              ),
        child: widget.child,
      ),
    );
  }
}

class _LightSplat {
  final Offset position;
  final double strength;
  double age = 0;

  _LightSplat({
    required this.position,
    required this.strength,
  });
}

class _LightShaderPainter extends CustomPainter {
  final List<_LightSplat> splats;
  final CosmoThemeTokens tokens;

  _LightShaderPainter({
    required this.splats,
    required this.tokens,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final paint = Paint()..blendMode = BlendMode.srcOver;

    for (final splat in splats) {
      final t = splat.age.clamp(0.0, 1.0);
      final fade = math.pow(1 - t, 2).toDouble();
      final expansion = Curves.easeOutCubic.transform(t);
      final radius = (96 + 74 * splat.strength) * (0.72 + expansion * 0.52);
      final opacity = (0.18 * splat.strength * fade).clamp(0.0, 0.22);

      paint.shader = RadialGradient(
        colors: [
          tokens.focusAccent.withValues(alpha: opacity),
          tokens.secondaryAccent.withValues(alpha: opacity * 0.42),
          tokens.background.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.46, 1.0],
      ).createShader(
        Rect.fromCircle(center: splat.position, radius: radius),
      );

      canvas.drawCircle(splat.position, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LightShaderPainter oldDelegate) {
    return oldDelegate.tokens != tokens;
  }
}
