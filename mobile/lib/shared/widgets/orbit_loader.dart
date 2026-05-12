import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/nebula_colors.dart';

/// Rotating arc of light — Nebula-native loading indicator.
/// Replaces standard CircularProgressIndicator across the app.
class OrbitLoader extends StatefulWidget {
  final Color? color;
  final double size;

  const OrbitLoader({super.key, this.color, this.size = 28});

  @override
  State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? NebulaColors.stellarBlue;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _OrbitPainter(
          progress: _ctrl.value,
          color: color,
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double progress;
  final Color color;

  _OrbitPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 3;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Dim track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Arc of light — segment-based fade from transparent to full opacity
    final startAngle = -math.pi / 2 + progress * 2 * math.pi;
    const arcAngle = 1.5; // ~86 degrees
    const segments = 14;

    for (int i = 0; i < segments; i++) {
      final t = i / segments;
      final segStart = startAngle + t * arcAngle;
      const segSweep = arcAngle / segments + 0.01; // tiny overlap avoids gaps
      canvas.drawArc(
        rect,
        segStart,
        segSweep,
        false,
        Paint()
          ..color = color.withValues(alpha: t * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap =
              i == segments - 1 ? StrokeCap.round : StrokeCap.butt,
      );
    }

    // Glow dot at leading tip
    final tipAngle = startAngle + arcAngle;
    final tipX = center.dx + radius * math.cos(tipAngle);
    final tipY = center.dy + radius * math.sin(tipAngle);
    canvas.drawCircle(
      Offset(tipX, tipY),
      2.5,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(tipX, tipY),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.progress != progress;
}
