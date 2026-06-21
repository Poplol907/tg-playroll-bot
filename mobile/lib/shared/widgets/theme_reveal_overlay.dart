import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_visual_mode.dart';
import '../../core/theme/nebula_tokens.dart';

enum ThemeRevealDirection {
  edgesToCenter,
  centerToEdges,
}

/// Shared geometry for the theme reveal and its regression tests.
abstract final class ThemeRevealGeometry {
  static const double _feather = 0.12;

  static double oldFrameOpacity({
    required ThemeRevealDirection direction,
    required double progress,
    required double normalizedRadius,
  }) {
    final t = progress.clamp(0.0, 1.0);
    final radius = normalizedRadius.clamp(0.0, 1.0);

    return switch (direction) {
      ThemeRevealDirection.edgesToCenter =>
        ((_lerp(1 + _feather, -_feather, t) - radius) / _feather)
            .clamp(0.0, 1.0),
      ThemeRevealDirection.centerToEdges =>
        ((radius - _lerp(-_feather, 1 + _feather, t)) / _feather)
            .clamp(0.0, 1.0),
    };
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}

/// Captures the current app frame before a theme change and reveals the new
/// theme beneath it. This keeps the transition global and avoids per-screen
/// theme animations that drift out of sync.
class ThemeRevealOverlay extends ConsumerStatefulWidget {
  final Widget child;

  const ThemeRevealOverlay({
    super.key,
    required this.child,
  });

  static Future<bool> switchMode(
    BuildContext context,
    AppVisualMode mode,
  ) async {
    final scope = context.getInheritedWidgetOfExactType<_ThemeRevealScope>();
    if (scope == null) return false;
    await scope.switchMode(mode);
    return true;
  }

  @override
  ConsumerState<ThemeRevealOverlay> createState() => _ThemeRevealOverlayState();
}

class _ThemeRevealOverlayState extends ConsumerState<ThemeRevealOverlay>
    with SingleTickerProviderStateMixin {
  final GlobalKey _boundaryKey = GlobalKey();
  late final AnimationController _controller;
  ui.Image? _oldFrame;
  ThemeRevealDirection _direction = ThemeRevealDirection.edgesToCenter;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: NebulaTokens.screenTransition,
    );
  }

  @override
  void dispose() {
    _oldFrame?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _switchMode(AppVisualMode next) async {
    final current = ref.read(appVisualModeProvider);
    if (_switching || current == next) return;

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      ref.read(appVisualModeProvider.notifier).state = next;
      return;
    }

    _switching = true;
    ui.Image? frame;
    try {
      // The tap ripple can still be dirty in this frame. Capture only after it
      // has painted so RenderRepaintBoundary always returns a complete image.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final boundary = _boundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) {
        ref.read(appVisualModeProvider.notifier).state = next;
        return;
      }

      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      frame = await boundary.toImage(pixelRatio: pixelRatio);
      if (!mounted) {
        frame.dispose();
        return;
      }

      _oldFrame?.dispose();
      setState(() {
        _oldFrame = frame;
        _direction = next == AppVisualMode.lightLite
            ? ThemeRevealDirection.edgesToCenter
            : ThemeRevealDirection.centerToEdges;
      });

      ref.read(appVisualModeProvider.notifier).state = next;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      await _controller.forward(from: 0);
      if (!mounted) return;

      setState(() {
        _oldFrame?.dispose();
        _oldFrame = null;
      });
      frame = null;
    } finally {
      if (frame != null && mounted) {
        if (identical(frame, _oldFrame)) {
          setState(() => _oldFrame = null);
        }
        frame.dispose();
      }
      _switching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ThemeRevealScope(
      switchMode: _switchMode,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(key: _boundaryKey, child: widget.child),
          if (_oldFrame != null)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _ThemeRevealPainter(
                      image: _oldFrame!,
                      direction: _direction,
                      progress: Curves.easeInOutCubicEmphasized
                          .transform(_controller.value),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ThemeRevealScope extends InheritedWidget {
  final Future<void> Function(AppVisualMode) switchMode;

  const _ThemeRevealScope({
    required this.switchMode,
    required super.child,
  });

  @override
  bool updateShouldNotify(_ThemeRevealScope oldWidget) => false;
}

class _ThemeRevealPainter extends CustomPainter {
  final ui.Image image;
  final ThemeRevealDirection direction;
  final double progress;

  const _ThemeRevealPainter({
    required this.image,
    required this.direction,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final center = size.center(Offset.zero);
    final maxRadius = math.sqrt(
          size.width * size.width + size.height * size.height,
        ) /
        2;
    final imageBounds = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );

    canvas.saveLayer(bounds, Paint());
    canvas.drawImageRect(image, imageBounds, bounds, Paint());

    const sampleCount = 32;
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= sampleCount; i++) {
      final radius = i / sampleCount;
      final opacity = ThemeRevealGeometry.oldFrameOpacity(
        direction: direction,
        progress: progress,
        normalizedRadius: radius,
      );
      colors.add(Colors.white.withValues(alpha: opacity));
      stops.add(radius);
    }

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.radial(center, maxRadius, colors, stops)
        ..blendMode = BlendMode.dstIn,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThemeRevealPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.direction != direction ||
      oldDelegate.progress != progress;
}
