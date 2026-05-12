import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/theme/nebula_colors.dart';

// ─────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────

class _Star {
  final double x, y;
  final double vx, vy;
  final double radius;
  final double baseOpacity;
  final double twinklePhase;
  final double twinkleSpeed;
  double px, py;

  _Star({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
    required this.baseOpacity,
    required this.twinklePhase,
    required this.twinkleSpeed,
  })  : px = x,
        py = y;
}

class _ShootingStar {
  double x, y;
  final double angle;
  final double speed;
  final double length;
  double opacity = 0.9;
  bool active = true;

  _ShootingStar({
    required this.x,
    required this.y,
    required this.angle,
    required this.speed,
    required this.length,
  });
}

/// Fluid nebula cloud with pre-cached gradient — avoids per-frame allocation.
class _NebulaCloud {
  final double baseX, baseY;
  final double radius;

  // Drift
  final double driftAmpX, driftAmpY;
  final double driftPhase;
  final double driftSpeedX, driftSpeedY;

  // Spring state
  double dispX = 0, dispY = 0;
  double velX  = 0, velY  = 0;

  // Drawn position
  double px, py;

  // Gradient cached once — colors never change, only position does
  late final RadialGradient gradient;

  _NebulaCloud({
    required this.baseX,
    required this.baseY,
    required this.radius,
    required Color color,
    required double alpha,
    required this.driftAmpX,
    required this.driftAmpY,
    required this.driftPhase,
    required this.driftSpeedX,
    required this.driftSpeedY,
  })  : px = baseX,
        py = baseY {
    gradient = RadialGradient(
      colors: [
        color.withValues(alpha: alpha),
        color.withValues(alpha: alpha * 0.50),
        color.withValues(alpha: alpha * 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.28, 0.62, 1.0],
    );
  }

  bool get hasMotion => velX.abs() > 0.3 || velY.abs() > 0.3;
}

// ─────────────────────────────────────────────
//  REPAINT NOTIFIER — manual rate control
// ─────────────────────────────────────────────

class _RepaintNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

// ─────────────────────────────────────────────
//  WIDGET
// ─────────────────────────────────────────────

/// Optimised animated nebula background.
///
/// Performance design:
///  • BackdropFilter cost ∝ sigma² — blur sigmas kept low in NebulaTokens
///  • Background paints at 30fps when idle, 60fps when shooting star/physics active
///  • Clouds use pre-cached RadialGradient — zero per-frame allocation
///  • Manual repaint notifier decouples paint rate from ticker rate
///  • shouldRepaint returns false — repaint listenable drives everything
///  • Touch: tap pushes clouds radially, drag flows them like liquid
///  • transparent: true → renders nothing; returns child as-is (for global bg)
class NebulaBackground extends StatefulWidget {
  final Widget child;
  final bool interactive;
  final bool transparent;

  const NebulaBackground({
    super.key,
    required this.child,
    this.interactive = true,
    this.transparent = false,
  });

  @override
  State<NebulaBackground> createState() => _NebulaBackgroundState();
}

class _NebulaBackgroundState extends State<NebulaBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {

  late Ticker _ticker;
  final _repaint = _RepaintNotifier();

  final _rng = Random(0xAE27B4); // fixed seed = spatial memory

  final List<_Star>         _stars         = [];
  final List<_ShootingStar> _shootingStars = [];
  final List<_NebulaCloud>  _clouds        = [];

  double _shootingStarTimer    = 0;
  double _shootingStarInterval = 5.0;
  Size   _size                 = Size.zero;
  double _t                    = 0; // seconds since start
  double _dt                   = 0;
  int    _frame                = 0;

  // ── init ──────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    if (!widget.transparent) _ticker.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.transparent) return;
    // Stop burning CPU/GPU when app is backgrounded
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _ticker.stop();
    } else if (state == AppLifecycleState.resumed && !_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.transparent) return;
    if (MediaQuery.of(context).disableAnimations) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  void _initStars(Size size) {
    if (_stars.isNotEmpty) return;
    _size = size;
    const count = 45; // lean budget — still looks rich
    for (int i = 0; i < count; i++) {
      _stars.add(_Star(
        x: _rng.nextDouble() * size.width,
        y: _rng.nextDouble() * size.height,
        vx: (_rng.nextDouble() - 0.5) * 0.14,
        vy: (_rng.nextDouble() - 0.5) * 0.14,
        radius: _rng.nextDouble() * 1.2 + 0.3,
        baseOpacity: _rng.nextDouble() * 0.45 + 0.18,
        twinklePhase: _rng.nextDouble() * pi * 2,
        twinkleSpeed: _rng.nextDouble() * 1.2 + 0.3,
      ));
    }
    _shootingStarInterval = 5.0 + _rng.nextDouble() * 6.0;
  }

  void _initClouds(Size size) {
    if (_clouds.isNotEmpty) return;
    final w = size.width;
    final h = size.height;

    // 5 clouds — positions spread across screen, colors overlap for depth
    final defs = [
      //  color,                    bX,       bY,       r,     alpha,  aX,   aY,  phase, sX,    sY
      [NebulaColors.nebulaPurple,  w * 0.15, h * 0.20, 300.0, 0.14, 22.0, 16.0,  0.0,  0.04,  0.03],
      [NebulaColors.stellarBlue,   w * 0.82, h * 0.18, 260.0, 0.12, 16.0, 13.0,  1.2,  0.05,  0.04],
      [NebulaColors.milkyGlow,     w * 0.50, h * 0.52, 360.0, 0.07, 28.0, 22.0,  2.4,  0.03,  0.05],
      [NebulaColors.auroraCyan,    w * 0.22, h * 0.78, 280.0, 0.09, 18.0, 14.0,  3.6,  0.05,  0.06],
      [NebulaColors.nebulaPurple,  w * 0.72, h * 0.72, 320.0, 0.08, 14.0, 17.0,  0.8,  0.06,  0.04],
    ];

    for (final d in defs) {
      _clouds.add(_NebulaCloud(
        baseX:       d[1] as double,
        baseY:       d[2] as double,
        radius:      d[3] as double,
        color:       d[0] as Color,
        alpha:       d[4] as double,
        driftAmpX:   d[5] as double,
        driftAmpY:   d[6] as double,
        driftPhase:  d[7] as double,
        driftSpeedX: d[8] as double,
        driftSpeedY: d[9] as double,
      ));
    }
  }

  // ── tick ──────────────────────────────────────────────────────────────────

  void _onTick(Duration elapsed) {
    final now = elapsed.inMicroseconds / 1e6;
    _dt = min(now - _t, 0.05);
    _t  = now;
    _frame++;

    if (_size == Size.zero) return;

    // Stars drift every frame (pure addition — negligible cost)
    for (final s in _stars) {
      s.px += s.vx;
      s.py += s.vy;
      if (s.px < 0)          s.px += _size.width;
      if (s.px > _size.width)  s.px -= _size.width;
      if (s.py < 0)          s.py += _size.height;
      if (s.py > _size.height) s.py -= _size.height;
    }

    // Shooting stars
    _shootingStarTimer += _dt;
    if (_shootingStarTimer >= _shootingStarInterval) {
      _shootingStarTimer    = 0;
      _shootingStarInterval = 4.0 + _rng.nextDouble() * 7.0;
      _spawnShootingStar();
    }
    bool anyShootingActive = false;
    for (final ss in _shootingStars) {
      if (!ss.active) continue;
      anyShootingActive = true;
      ss.x += cos(ss.angle) * ss.speed;
      ss.y += sin(ss.angle) * ss.speed;
      ss.opacity -= 0.013;
      if (ss.opacity <= 0 ||
          ss.x < -200 || ss.x > _size.width  + 200 ||
          ss.y < -200 || ss.y > _size.height + 200) {
        ss.active = false;
        anyShootingActive = false;
      }
    }
    _shootingStars.removeWhere((s) => !s.active);

    // Cloud physics — check if any spring is still moving
    bool cloudActive = false;
    for (final c in _clouds) { if (c.hasMotion) { cloudActive = true; break; } }

    // Rate control:
    //   - 60fps when shooting star is visible
    //   - 30fps when cloud springs are active (touch interaction settling)
    //   - 20fps (every 3rd frame) during ambient idle drift
    if (anyShootingActive) {
      // full speed — nothing to skip
    } else if (cloudActive) {
      if (_frame % 2 != 0) return; // 30fps
    } else {
      if (_frame % 3 != 0) return; // 20fps idle
    }

    _updateClouds();
    _repaint.ping();
  }

  void _updateClouds() {
    const springK  = 1.4;
    const damping  = 2.4;

    for (final c in _clouds) {
      final ambX = c.driftAmpX * sin(_t * c.driftSpeedX + c.driftPhase);
      final ambY = c.driftAmpY * cos(_t * c.driftSpeedY + c.driftPhase + 1.3);

      final fx = -springK * c.dispX - damping * c.velX;
      final fy = -springK * c.dispY - damping * c.velY;
      c.velX += fx * _dt;
      c.velY += fy * _dt;
      c.dispX += c.velX * _dt;
      c.dispY += c.velY * _dt;

      c.px = c.baseX + ambX + c.dispX;
      c.py = c.baseY + ambY + c.dispY;
    }
  }

  void _spawnShootingStar() {
    final angle = pi / 6 + _rng.nextDouble() * pi / 6;
    _shootingStars.add(_ShootingStar(
      x:      _rng.nextDouble() * _size.width * 0.5,
      y:      _rng.nextDouble() * _size.height * 0.3,
      angle:  angle,
      speed:  7.0 + _rng.nextDouble() * 5.0,
      length: 65 + _rng.nextDouble() * 45,
    ));
  }

  // ── touch interaction ─────────────────────────────────────────────────────

  void _onTapDown(TapDownDetails d) {
    if (!widget.interactive) return;
    final pos = d.localPosition;
    for (final c in _clouds) {
      final dx = c.px - pos.dx;
      final dy = c.py - pos.dy;
      final r  = sqrt(dx * dx + dy * dy);
      if (r < 400 && r > 1) {
        final impulse = 50.0 * max(0.0, 1 - r / 400);
        c.velX += (dx / r) * impulse;
        c.velY += (dy / r) * impulse;
      }
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (!widget.interactive) return;
    final pos   = d.localPosition;
    final delta = d.delta;
    const sigma = 210.0;

    for (final c in _clouds) {
      final dx = c.px - pos.dx;
      final dy = c.py - pos.dy;
      final w  = exp(-(dx * dx + dy * dy) / (sigma * sigma));
      c.velX += delta.dx * w * 0.12;
      c.velY += delta.dy * w * 0.12;
    }
  }

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // transparent mode — just pass through the child, zero rendering cost
    if (widget.transparent) return widget.child;

    return GestureDetector(
      onTapDown:  _onTapDown,
      onPanUpdate: _onPanUpdate,
      behavior: HitTestBehavior.translucent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _initStars(size);
          _initClouds(size);
          return Stack(
            children: [
              const ColoredBox(color: NebulaColors.deepVoid, child: SizedBox.expand()),
              RepaintBoundary(
                child: CustomPaint(
                  size: size,
                  painter: _NebulaFieldPainter(
                    stars:         _stars,
                    shootingStars: _shootingStars,
                    clouds:        _clouds,
                    time:          _t,
                    repaint:       _repaint,
                  ),
                ),
              ),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  PAINTER
// ─────────────────────────────────────────────

class _NebulaFieldPainter extends CustomPainter {
  final List<_Star>         stars;
  final List<_ShootingStar> shootingStars;
  final List<_NebulaCloud>  clouds;
  final double              time;

  _NebulaFieldPainter({
    required this.stars,
    required this.shootingStars,
    required this.clouds,
    required this.time,
    required Listenable repaint,
  }) : super(repaint: repaint);

  // Reuse single Paint object — no per-draw allocation
  final _p = Paint()..style = PaintingStyle.fill;

  @override
  void paint(Canvas canvas, Size size) {
    _drawClouds(canvas);
    _drawStars(canvas);
    _drawShootingStars(canvas);
  }

  void _drawClouds(Canvas canvas) {
    _p.maskFilter = null;
    for (final c in clouds) {
      final center = Offset(c.px, c.py);
      // createShader is the only per-frame call — gradient itself is pre-cached
      _p.shader = c.gradient.createShader(
        Rect.fromCircle(center: center, radius: c.radius),
      );
      canvas.drawCircle(center, c.radius, _p);
    }
    _p.shader = null;
  }

  void _drawStars(Canvas canvas) {
    for (final s in stars) {
      final twinkle = (sin(time * s.twinkleSpeed + s.twinklePhase) + 1) * 0.5;
      final opacity = s.baseOpacity * (0.6 + 0.4 * twinkle);
      final pos     = Offset(s.px, s.py);

      if (s.radius > 1.0) {
        _p.color = NebulaColors.auroraCyan.withValues(alpha: opacity * 0.09);
        canvas.drawCircle(pos, s.radius * 3.0, _p);
      }
      _p.color = Colors.white.withValues(alpha: opacity);
      canvas.drawCircle(pos, s.radius, _p);
    }
  }

  void _drawShootingStars(Canvas canvas) {
    for (final ss in shootingStars) {
      if (!ss.active) continue;
      final tailX = ss.x - cos(ss.angle) * ss.length;
      final tailY = ss.y - sin(ss.angle) * ss.length;
      final head  = Offset(ss.x, ss.y);
      final tail  = Offset(tailX, tailY);

      _p
        ..maskFilter = null
        ..shader = LinearGradient(
          colors: [
            Colors.white.withValues(alpha: ss.opacity),
            NebulaColors.auroraCyan.withValues(alpha: ss.opacity * 0.35),
            Colors.transparent,
          ],
        ).createShader(Rect.fromPoints(head, tail))
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(head, tail, _p);

      // Small glow dot at head — single small blur (sigma=2) is fine
      _p
        ..shader = null
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: ss.opacity * 0.70)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(head, 1.6, _p);
      _p.maskFilter = null;
    }
  }

  // repaint listenable drives all redraws — no extra repaints on widget rebuild
  @override
  bool shouldRepaint(_NebulaFieldPainter old) => false;
}
