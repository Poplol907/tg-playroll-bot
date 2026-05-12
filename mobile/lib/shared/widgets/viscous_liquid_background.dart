import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  ViscousLiquidBackground — light-theme counterpart to AsciiWaterBackground.
//
//  Visual goal: "ink on wet paper" — touch injects slowly spreading
//  iridescent watercolor blobs on a cream canvas. Identical wave physics
//  to the ASCII sim (Laplacian propagation, zero-alloc ping-pong buffers)
//  so the feel is consistent when cycling themes.
//
//  Pipeline per frame:
//   1. Idle drift — gentle sinusoidal splat keeps the canvas alive
//   2. Touch splat — inject wave height + dye at pointer
//   3. Wave propagate — Laplacian step, swap buffers (zero alloc)
//   4. Dye diffuse — neighbour spread + slow decay
//   5. Render — radial gradient blobs coloured by per-cell hue field
// ─────────────────────────────────────────────────────────────────────────────

const int _kCellPx = 10; // logical px per sim cell

class _LiquidData {
  int cols = 0, rows = 0;
  Float32List wave    = Float32List(0); // height (current frame)
  Float32List waveSwp = Float32List(0); // pre-allocated swap buffer
  Float32List dye     = Float32List(0); // dye intensity [0..1]
  Float32List dyeSwp  = Float32List(0);
  Float32List hue     = Float32List(0); // per-cell hue [0..360)
}

class _Notifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

// ─────────────────────────────────────────────────────────────────────────────

class ViscousLiquidBackground extends StatefulWidget {
  final Widget child;

  const ViscousLiquidBackground({super.key, required this.child});

  @override
  State<ViscousLiquidBackground> createState() =>
      _ViscousLiquidBackgroundState();
}

class _ViscousLiquidBackgroundState extends State<ViscousLiquidBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _data    = _LiquidData();
  final _repaint = _Notifier();
  Size _size     = Size.zero;

  double _px = -1, _py = -1;
  bool   _down = false;
  double _t    = 0; // elapsed seconds for idle drift

  // Wave / dye params tuned for "thick liquid" feel.
  static const _waveSpeed  = 0.32; // slower than ASCII → heavier feel
  static const _damping    = 0.965; // slower decay → waves linger longer
  static const _dyeDecay   = 0.9990; // dye stays visible ~10 s
  static const _dyeSpread  = 0.06;  // gentle diffusion each frame

  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    _ticker.muted =
        s == AppLifecycleState.paused || s == AppLifecycleState.detached;
  }

  // ── Grid init ──────────────────────────────────────────────────────────────

  void _initGrid(Size size) {
    if (size == _size) return;
    _size = size;
    final cols = (size.width  / _kCellPx).ceil() + 2;
    final rows = (size.height / _kCellPx).ceil() + 2;
    final n    = cols * rows;
    _data
      ..cols    = cols
      ..rows    = rows
      ..wave    = Float32List(n)
      ..waveSwp = Float32List(n)
      ..dye     = Float32List(n)
      ..dyeSwp  = Float32List(n)
      ..hue     = _buildHueField(cols, rows, n);
  }

  // Initialise each cell with a position-based hue so untouched regions
  // already carry a quiet chromatic field — visible only when dye arrives.
  Float32List _buildHueField(int cols, int rows, int n) {
    final h = Float32List(n);
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        h[y * cols + x] = (x * 5.7 + y * 8.3) % 360;
      }
    }
    return h;
  }

  // ── Splat ──────────────────────────────────────────────────────────────────

  void _splat(
    double px,
    double py, {
    double waveStr = 40.0,
    double radius  = 5.0,
    double? hueOverride,
  }) {
    final d = _data;
    if (d.cols == 0) return;
    final cx = (px / _kCellPx).round();
    final cy = (py / _kCellPx).round();
    final ri = radius.round();
    final r2 = radius * radius;

    for (int dy = -ri; dy <= ri; dy++) {
      for (int dx = -ri; dx <= ri; dx++) {
        final dist2 = (dx * dx + dy * dy).toDouble();
        if (dist2 > r2) continue;
        final nx = cx + dx;
        final ny = cy + dy;
        if (nx < 1 || nx >= d.cols - 1 || ny < 1 || ny >= d.rows - 1) continue;
        final idx     = ny * d.cols + nx;
        final falloff = math.exp(-dist2 / (r2 * 0.5));
        d.wave[idx]   = (d.wave[idx] + waveStr * falloff).clamp(-120.0, 120.0);
        final amt = 0.5 + 0.5 * falloff;
        if (d.dye[idx] < amt) {
          d.dye[idx] = amt;
          if (hueOverride != null) d.hue[idx] = hueOverride;
        }
      }
    }
  }

  // ── Idle drift — keeps canvas alive before first touch ────────────────────

  void _idleDrift() {
    final cx = _size.width  * (0.5 + 0.28 * math.sin(_t * 0.19));
    final cy = _size.height * (0.5 + 0.22 * math.cos(_t * 0.14));
    final hue = (_t * 18.0) % 360;
    _splat(cx, cy, waveStr: 6.0, radius: 3.5, hueOverride: hue);
  }

  // ── Sim step ───────────────────────────────────────────────────────────────

  void _step() {
    final d    = _data;
    final cols = d.cols;
    final rows = d.rows;
    if (cols == 0) return;

    final cur = d.wave;
    final nxt = d.waveSwp;
    const spd = _waveSpeed * _waveSpeed;

    // Wave propagation — Laplacian, zero-alloc swap.
    for (int y = 1; y < rows - 1; y++) {
      final row = y * cols;
      for (int x = 1; x < cols - 1; x++) {
        final i   = row + x;
        final lap = cur[i - 1] + cur[i + 1] + cur[i - cols] + cur[i + cols]
                    - 4.0 * cur[i];
        nxt[i]    = (cur[i] + spd * lap) * _damping;
      }
    }
    d.wave    = nxt;
    d.waveSwp = cur; // swap references, zero alloc

    // Dye diffusion + decay.
    final dye    = d.dye;
    final dyeNxt = d.dyeSwp;
    for (int y = 1; y < rows - 1; y++) {
      final row = y * cols;
      for (int x = 1; x < cols - 1; x++) {
        final i    = row + x;
        final avg  = (dye[i - 1] + dye[i + 1] + dye[i - cols] + dye[i + cols])
                     * 0.25;
        dyeNxt[i]  = (dye[i] * (1.0 - _dyeSpread) + avg * _dyeSpread)
                     * _dyeDecay;
      }
    }
    d.dye    = dyeNxt;
    d.dyeSwp = dye;
  }

  // ── Ticker callback ───────────────────────────────────────────────────────

  void _tick(Duration elapsed) {
    if (_size == Size.zero) return;
    final dt = _lastElapsed == Duration.zero
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1e6;
    _lastElapsed = elapsed;
    final cdt = dt.clamp(0.0, 0.05);

    _t += cdt;
    _idleDrift();

    if (_down && _px >= 0) {
      final hue = (_px / _size.width * 200 + _py / _size.height * 120) % 360;
      _splat(_px, _py, waveStr: 60.0, radius: 7.0, hueOverride: hue);
    }

    _step();
    _repaint.ping();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _initGrid(constraints.biggest);
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (e) {
            _down = true;
            _px   = e.localPosition.dx;
            _py   = e.localPosition.dy;
            final hue =
                (_px / _size.width * 200 + _py / _size.height * 120) % 360;
            _splat(_px, _py, waveStr: 90.0, radius: 9.0, hueOverride: hue);
          },
          onPointerMove: (e) {
            _px = e.localPosition.dx;
            _py = e.localPosition.dy;
          },
          onPointerUp:     (_) => _down = false,
          onPointerCancel: (_) => _down = false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _repaint,
                  builder: (_, __) => CustomPaint(
                    painter: _LiquidPainter(_data),
                    size: constraints.biggest,
                  ),
                ),
              ),
              widget.child,
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter — radial gradient blobs on cream canvas
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidPainter extends CustomPainter {
  final _LiquidData data;

  _LiquidPainter(this.data);

  static const Color _bg = Color(0xFFFAFAF7); // warm cream — matches lightShader bg

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _bg);

    final d = data;
    if (d.cols == 0) return;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int y = 1; y < d.rows - 1; y++) {
      final row = y * d.cols;
      for (int x = 1; x < d.cols - 1; x++) {
        final i      = row + x;
        final dyeVal = d.dye[i];
        if (dyeVal < 0.012) continue;

        // Wave adds a subtle intensity boost at peaks.
        final waveBoost = (d.wave[i].abs() / 120.0).clamp(0.0, 0.25);
        final intensity = (dyeVal + waveBoost * 0.3).clamp(0.0, 1.0);

        final cx = (x - 0.5) * _kCellPx.toDouble();
        final cy = (y - 0.5) * _kCellPx.toDouble();

        // Blob radius grows with intensity — more dye = larger soft patch.
        final blobR = _kCellPx * (1.2 + intensity * 2.0);

        final color = HSLColor.fromAHSL(
          (intensity * 0.32).clamp(0.0, 0.32), // alpha — soft watercolour
          d.hue[i],
          0.55 + intensity * 0.20, // saturation
          0.62,                    // lightness — pastel, not garish
        ).toColor();

        paint.shader = RadialGradient(
          colors: [color, color.withAlpha(0)],
        ).createShader(Rect.fromCircle(
          center: Offset(cx, cy),
          radius: blobR,
        ));

        canvas.drawCircle(Offset(cx, cy), blobR, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_LiquidPainter _) => true;
}
