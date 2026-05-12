import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';

class CosmoLoginSphere extends StatefulWidget {
  final CosmoThemeTokens tokens;
  final double size;
  final bool enableAmbientMotion;
  final VoidCallback? onDebugAnimationTick;

  const CosmoLoginSphere({
    super.key,
    required this.tokens,
    this.size = 220,
    this.enableAmbientMotion = false,
    this.onDebugAnimationTick,
  });

  @override
  State<CosmoLoginSphere> createState() => _CosmoLoginSphereState();
}

class _CosmoLoginSphereState extends State<CosmoLoginSphere>
    with TickerProviderStateMixin {
  late final AnimationController _glowController;
  late final AnimationController _rotateController;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
      value: 0.72,
    );
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
      value: 0.18,
    )..addListener(_debugAnimationTick);
    _glow = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAmbientMotion();
  }

  void _syncAmbientMotion() {
    if (MediaQuery.of(context).disableAnimations) {
      _glowController
        ..stop()
        ..value = 0.72;
      _rotateController
        ..stop()
        ..value = 0.18;
    } else if (!widget.enableAmbientMotion) {
      _glowController
        ..stop()
        ..value = 0.72;
      _rotateController
        ..stop()
        ..value = 0.18;
    } else {
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
      if (!_rotateController.isAnimating) {
        _rotateController.repeat();
      }
    }
  }

  void _debugAnimationTick() {
    if (!widget.enableAmbientMotion || !_rotateController.isAnimating) return;
    widget.onDebugAnimationTick?.call();
  }

  @override
  void didUpdateWidget(CosmoLoginSphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableAmbientMotion != widget.enableAmbientMotion) {
      _syncAmbientMotion();
    }
  }

  @override
  void dispose() {
    _rotateController.removeListener(_debugAnimationTick);
    _glowController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glow, _rotateController]),
      builder: (context, _) => SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _CosmoLoginSpherePainter(
            tokens: widget.tokens,
            glow: _glow.value,
            spin: _rotateController.value,
          ),
        ),
      ),
    );
  }
}

class _CosmoLoginSpherePainter extends CustomPainter {
  final CosmoThemeTokens tokens;
  final double glow;
  final double spin;

  _CosmoLoginSpherePainter({
    required this.tokens,
    required this.glow,
    required this.spin,
  });

  static const _chars = '░▒▓█▀▄▌▐│─┤├┴┬╭╮╰╯';
  static final _paragraphStyle =
      ui.ParagraphStyle(fontFamily: 'Courier', fontSize: 8.5);
  static const _paragraphConstraints = ui.ParagraphConstraints(width: 12);

  bool get _isLight => tokens.background.computeLuminance() > 0.5;

  void _drawChar(
    Canvas canvas,
    String char,
    double x,
    double y,
    Color color,
    double alpha,
  ) {
    if (alpha < 0.04) return;
    final paragraph = (ui.ParagraphBuilder(_paragraphStyle)
          ..pushStyle(
            ui.TextStyle(
              color: color.withValues(alpha: alpha.clamp(0.0, 1.0)),
              fontSize: 8.5,
            ),
          )
          ..addText(char))
        .build()
      ..layout(_paragraphConstraints);
    canvas.drawParagraph(paragraph, Offset(x - 3.5, y - 5.0));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.39;
    final auraRadius = radius * 2.15;

    final auraAccent = _isLight ? tokens.primaryText : tokens.focusAccent;
    canvas.drawCircle(
      center,
      auraRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            auraAccent.withValues(alpha: (_isLight ? 0.07 : 0.18) * glow),
            tokens.secondaryAccent
                .withValues(alpha: (_isLight ? 0.035 : 0.08) * glow),
            Colors.transparent,
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: auraRadius)),
    );

    final pointStep = _isLight ? 0.24 : 0.19;
    final rotY = spin * pi * 2;
    final rotX = spin * pi * 0.85;
    final points = <_SpherePoint>[];

    for (var phi = 0.0; phi < pi * 2; phi += pointStep) {
      for (var theta = 0.0; theta < pi; theta += pointStep) {
        final sourceX = sin(theta) * cos(phi + spin * pi);
        final sourceY = sin(theta) * sin(phi + spin * pi);
        final sourceZ = cos(theta);

        final yRotX = sourceX * cos(rotY) - sourceZ * sin(rotY);
        final yRotZ = sourceX * sin(rotY) + sourceZ * cos(rotY);
        final xRotY = sourceY * cos(rotX) - yRotZ * sin(rotX);
        final finalZ = sourceY * sin(rotX) + yRotZ * cos(rotX);
        final depth = ((finalZ + 1) / 2).clamp(0.0, 1.0);
        final charIndex =
            (depth * (_chars.length - 1)).round().clamp(0, _chars.length - 1);

        points.add(
          _SpherePoint(
            x: center.dx + yRotX * radius,
            y: center.dy + xRotY * radius,
            z: finalZ,
            char: _chars[charIndex],
            depth: depth,
          ),
        );
      }
    }

    points.sort((a, b) => a.z.compareTo(b.z));

    for (final point in points) {
      final color = _isLight
          ? Color.lerp(tokens.mutedText, tokens.primaryText, point.depth)!
          : Color.lerp(
              tokens.secondaryAccent, tokens.focusAccent, point.depth)!;
      final alpha =
          (_isLight ? 0.18 + point.depth * 0.42 : 0.22 + point.depth * 0.58)
              .clamp(0.0, 1.0);
      _drawChar(canvas, point.char, point.x, point.y, color, alpha * glow);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmoLoginSpherePainter oldDelegate) {
    return oldDelegate.tokens != tokens ||
        oldDelegate.glow != glow ||
        oldDelegate.spin != spin;
  }
}

class _SpherePoint {
  final double x;
  final double y;
  final double z;
  final String char;
  final double depth;

  const _SpherePoint({
    required this.x,
    required this.y,
    required this.z,
    required this.char,
    required this.depth,
  });
}
