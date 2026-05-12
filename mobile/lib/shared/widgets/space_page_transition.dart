import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/nebula_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Spacemorphism transition
//
//  Effect: the current view dissolves into a swirling nebula, then the nebula
//  disperses and the new view crystallises from the void — like flying through
//  an interstellar cloud.
//
//  Ghost-fix: solid black floor is always the bottom layer of the stack, so
//  the previous route can never bleed through even during scale/opacity ramps.
// ─────────────────────────────────────────────────────────────────────────────

class SpaceTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const SpaceTransition({
    super.key,
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // New screen crystallises from t=0.40 → 1.0 with a slight warp-drift
    final enterFade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.40, 1.0, curve: Curves.easeOut),
    );
    final enterDrift = Tween<Offset>(
      begin: const Offset(0.025, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: animation,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    ));

    return Stack(
      fit: StackFit.expand,
      children: [
        // ① Hard floor — kills ghosting completely
        const ColoredBox(color: NebulaColors.spaceBlack),

        // ② New screen drifts in through clearing nebula
        FadeTransition(
          opacity: enterFade,
          child: SlideTransition(position: enterDrift, child: child),
        ),

        // ③ Nebula overlay — present at t=0, disperses by t=0.78
        _NebulaOverlay(animation: animation),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Nebula overlay
// ─────────────────────────────────────────────────────────────────────────────

class _NebulaOverlay extends StatefulWidget {
  final Animation<double> animation;
  const _NebulaOverlay({required this.animation});

  @override
  State<_NebulaOverlay> createState() => _NebulaOverlayState();
}

class _NebulaOverlayState extends State<_NebulaOverlay> {
  late final List<_Cloud> _clouds;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);

    // Seven clouds — positions and drift vectors are fixed per transition
    _clouds = List.generate(7, (i) {
      return _Cloud(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        radius: 0.28 + rng.nextDouble() * 0.32,
        colorIndex: i % 3,
        drift: Offset(
          (rng.nextDouble() - 0.5) * 0.12,
          (rng.nextDouble() - 0.5) * 0.07,
        ),
        coreScale: 0.28 + rng.nextDouble() * 0.14,
      );
    });

    // 55 background stars
    _stars = List.generate(55, (_) {
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        r: 0.35 + rng.nextDouble() * 0.95,
        opacity: 0.25 + rng.nextDouble() * 0.75,
      );
    });

    widget.animation.addListener(_tick);
  }

  void _tick() => setState(() {});

  @override
  void dispose() {
    widget.animation.removeListener(_tick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.animation.value;

    // Nebula: fully opaque at t=0, gone by t=0.78
    final opacity = ((1.0 - t / 0.78)).clamp(0.0, 1.0);
    if (opacity < 0.005) return const SizedBox.shrink();

    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _NebulaPainter(
        clouds: _clouds,
        stars: _stars,
        opacity: opacity,
        t: t,
      ),
      child: const SizedBox.expand(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Data classes
// ─────────────────────────────────────────────────────────────────────────────

class _Cloud {
  final double x, y, radius, coreScale;
  final int colorIndex;
  final Offset drift;

  const _Cloud({
    required this.x,
    required this.y,
    required this.radius,
    required this.colorIndex,
    required this.drift,
    required this.coreScale,
  });
}

class _Star {
  final double x, y, r, opacity;
  const _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.opacity,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter
// ─────────────────────────────────────────────────────────────────────────────

class _NebulaPainter extends CustomPainter {
  final List<_Cloud> clouds;
  final List<_Star> stars;
  final double opacity;
  final double t;

  static const _cloudColors = [
    NebulaColors.auroraCyan,
    NebulaColors.nebulaPurple,
    Color(0xFF1A0F4E), // deep indigo
  ];

  _NebulaPainter({
    required this.clouds,
    required this.stars,
    required this.opacity,
    required this.t,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Deep space tint ───────────────────────────────────────────────────
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF04020E).withValues(alpha: 0.82 * opacity),
    );

    // ── Nebula clouds ─────────────────────────────────────────────────────
    for (final cloud in clouds) {
      final color = _cloudColors[cloud.colorIndex];

      // Clouds drift slightly as animation progresses (parallax feel)
      final cx = (cloud.x + cloud.drift.dx * t) * size.width;
      final cy = (cloud.y + cloud.drift.dy * t) * size.height;
      final r = cloud.radius * size.shortestSide;

      // Outer diffuse glow
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.30 * opacity),
              color.withValues(alpha: 0.10 * opacity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.50, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );

      // Bright inner core
      final cr = r * cloud.coreScale;
      canvas.drawCircle(
        Offset(cx, cy),
        cr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.18 * opacity),
              color.withValues(alpha: 0.42 * opacity),
              Colors.transparent,
            ],
            stops: const [0.0, 0.35, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: cr)),
      );
    }

    // ── Stars ─────────────────────────────────────────────────────────────
    final starPaint = Paint()..style = PaintingStyle.fill;
    for (final s in stars) {
      starPaint.color =
          Colors.white.withValues(alpha: (s.opacity * opacity).clamp(0, 1));
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height),
        s.r,
        starPaint,
      );
    }

    // ── Central lens flare — blooms as nebula clears ──────────────────────
    final flareOpacity = (1.0 - opacity) * 0.20;
    if (flareOpacity > 0.005) {
      final fr = size.shortestSide * 0.45;
      final centre = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(
        centre,
        fr,
        Paint()
          ..shader = RadialGradient(
            colors: [
              NebulaColors.auroraCyan.withValues(alpha: flareOpacity),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: fr)),
      );
    }

    // ── Spacemorphism edge vignette ───────────────────────────────────────
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.45 * opacity),
        ],
        stops: const [0.55, 1.0],
      ).createShader(
          Rect.fromCircle(center: size.center(Offset.zero), radius: size.longestSide * 0.65));
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_NebulaPainter old) =>
      old.opacity != opacity || old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
//  go_router adapters
// ─────────────────────────────────────────────────────────────────────────────

class SpacePageRoute<T> extends PageRouteBuilder<T> {
  SpacePageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 620),
          reverseTransitionDuration: const Duration(milliseconds: 480),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              SpaceTransition(
                animation: animation,
                secondaryAnimation: secondaryAnimation,
                child: child,
              ),
        );
}

CustomTransitionPage<T> spaceTransitionPage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 620),
    reverseTransitionDuration: const Duration(milliseconds: 480),
    transitionsBuilder: (context, animation, secondaryAnimation, child) =>
        SpaceTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: child,
        ),
  );
}

/// Lightweight crossfade for bottom-tab navigation.
/// No nebula overlay — just a quick, smooth opacity swap.
CustomTransitionPage<T> nebulaFadePage<T>({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      );
      final slide = Tween<Offset>(
        begin: const Offset(0.0, 0.04),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ));

      return SlideTransition(
        position: slide,
        child: FadeTransition(
          opacity: fade,
          child: child,
        ),
      );
    },
  );
}
