import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/services/repaint_pulse.dart';
import 'package:flutter/scheduler.dart';
import '../../core/theme/nebula_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AsciiWaterBackground
//  Full-screen ASCII water ripple simulation. Drop-in for NebulaBackground.
//
//  Architecture:
//  • Wave sim: Float32List laplacian propagation, O(n) per frame
//  • Render:   ui.ParagraphBuilder per visible cell in CustomPainter
//  • Ticker drives sim + repaint. RepaintBoundary isolates child subtree.
//  • Pointer events → ripples via Listener (doesn't block child scroll)
//  • App lifecycle: ticker pauses when backgrounded
// ─────────────────────────────────────────────────────────────────────────────

const String _kChars = ' .,:;|!ilIwWMB#@'; // 16 density levels
const int _kCellW = 8; // logical px per column
const int _kCellH = 13; // logical px per row

// ── Mutable wave state (shared between sim and painter via reference) ─────────
class _WaveData {
  int cols = 0, rows = 0;
  Float32List wave = Float32List(0); // current frame buffer
  Float32List next = Float32List(0); // pre-allocated swap buffer (no alloc per frame)
  Float32List vel = Float32List(0); // velocity, mutated in-place
  Uint8List cellR = Uint8List(0); // pre-computed nebula colors (0-255)
  Uint8List cellG = Uint8List(0);
  Uint8List cellB = Uint8List(0);
}

class _RepaintNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

// ─────────────────────────────────────────────────────────────────────────────
class AsciiWaterBackground extends StatefulWidget {
  final Widget child;
  final VoidCallback? onDebugTick;

  const AsciiWaterBackground({
    super.key,
    required this.child,
    this.onDebugTick,
  });

  @override
  State<AsciiWaterBackground> createState() => _AsciiWaterBackgroundState();
}

class _AsciiWaterBackgroundState extends State<AsciiWaterBackground>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late Ticker _ticker;
  final _data = _WaveData();
  final _repaint = _RepaintNotifier();
  Size _size = Size.zero;

  // ── Visibility fade ───────────────────────────────────────────────────────
  // ASCII is hidden at rest; fades in on touch, fades out after 1.5 s idle.
  late AnimationController _fadeCtrl;
  Timer? _fadeOutTimer;
  final List<Timer> _rippleTimers = [];

  // ── Pointer tracking ──────────────────────────────────────────────────────
  double _px = -1, _py = -1, _prevPx = -1, _prevPy = -1;
  bool _down = false;

  // ── Wave parameters (tuned for "droplet bubbling on water") ─────────────
  // The previous "cloth" preset (tension 0.94) preserved amplitude so well
  // that the dimple lingered as a permanent dark patch. Inverted now:
  // tension is mid-low so the surface RETURNS to flat reliably; damping is
  // mid so a couple of soft echoes get to fan out before they fade; the
  // impulse is small + narrow so each touch reads as a tiny "blip" instead
  // of a smear. Result: light little ripples that bubble, spread, and
  // vanish in under a second.
  static const _waveSpeed = 0.16; // brisk propagation → ripples actually radiate
  static const _damping = 0.88; // velocity fades fast — no chatter, no ringing
  static const _hoverStr = 0.06; // tiny pinch, not a smear
  static const _clickStr = 10.0; // single light "blip" on tap

  static const _tension = 0.78; // surface springs back → no lingering dark patch
  static const _hoverRad = 3; // small, focused dimple (real droplet size)
  static const _clickRad = 5;
  static const _eps = 0.001;

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    // Wake & repaint when a modal/dialog/sheet closes, so a stale dimmed
    // frame can't linger until the user taps. See RepaintPulse.
    RepaintPulse.notifier.addListener(_onRepaintPulse);

    // Fade in fast (80 ms) — first ripple appears without stutter.
    // Fade out matches the new "light ripple" feel — short and clean (700 ms).
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 700),
      value: 0.0, // starts hidden
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _ticker.stop();
      _fadeOutTimer?.cancel();
    }
    if (state == AppLifecycleState.resumed && _hasWaveEnergy()) {
      _ensureTickerRunning();
    }
  }

  void _onRepaintPulse() {
    // Force one fresh frame of the whole background subtree. Even though the
    // base colour is static, repainting recomposites the screen and clears
    // any stale barrier frame left behind by a just-closed overlay.
    if (!mounted) return;
    _repaint.ping();
    _ensureTickerRunning();
  }

  @override
  void dispose() {
    RepaintPulse.notifier.removeListener(_onRepaintPulse);
    _fadeOutTimer?.cancel();
    for (final timer in _rippleTimers) {
      timer.cancel();
    }
    _rippleTimers.clear();
    _fadeCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  // ── Fade helpers ──────────────────────────────────────────────────────────
  void _showAscii() {
    _fadeOutTimer?.cancel();
    _fadeOutTimer = null;
    _fadeCtrl.forward();
  }

  void _scheduleHide() {
    _fadeOutTimer?.cancel();
    // Short hold (1200 ms) — light ripples should be GONE by the time the
    // user looks away, not loiter as a dark patch.
    _fadeOutTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _fadeCtrl.reverse();
    });
  }

  // ── Grid initialisation ───────────────────────────────────────────────────
  void _initGrid(Size size) {
    if (size == _size) return;
    _size = size;
    _data.cols = (size.width / _kCellW).floor().clamp(1, 2000);
    _data.rows = (size.height / _kCellH).floor().clamp(1, 2000);
    final n = _data.cols * _data.rows;
    _data.wave = Float32List(n);
    _data.next = Float32List(n);
    _data.vel = Float32List(n);
    _data.cellR = Uint8List(n);
    _data.cellG = Uint8List(n);
    _data.cellB = Uint8List(n);
    _buildColors();
  }

  // Nebula cloud color field — 6 Gaussian cloud centers in accent palette
  void _buildColors() {
    final cols = _data.cols, rows = _data.rows;
    final rng = math.Random(0x4E3B1A);

    // (nx, ny, color, sigma, peak)
    const centers = [
      (0.15, 0.22, NebulaColors.nebulaPurple, 0.30, 0.85),
      (0.82, 0.18, NebulaColors.stellarBlue, 0.28, 0.75),
      (0.50, 0.55, NebulaColors.auroraCyan, 0.38, 0.60),
      (0.28, 0.78, NebulaColors.nebulaPurple, 0.22, 0.55),
      (0.75, 0.70, NebulaColors.stellarBlue, 0.26, 0.50),
      (0.60, 0.30, NebulaColors.auroraCyan, 0.18, 0.42),
    ];

    for (int i = 0; i < _data.cellR.length; i++) {
      final col = i % cols;
      final row = i ~/ cols;
      final nx = col / cols;
      final ny = row / rows;

      double R = 0, G = 0, B = 0;
      for (final c in centers) {
        final dx = nx - c.$1, dy = ny - c.$2;
        final w = c.$5 * math.exp(-(dx * dx + dy * dy) / (2 * c.$4 * c.$4));
        R += (c.$3.r * 255) * w;
        G += (c.$3.g * 255) * w;
        B += (c.$3.b * 255) * w;
      }

      // Scatter foreground stars (1.5% chance per cell)
      if (rng.nextDouble() < 0.015) {
        final s = rng.nextDouble() * 160 + 60;
        R = (R + s).clamp(0, 255);
        G = (G + s).clamp(0, 255);
        B = (B + s).clamp(0, 255);
      }

      _data.cellR[i] = R.clamp(0, 255).toInt();
      _data.cellG[i] = G.clamp(0, 255).toInt();
      _data.cellB[i] = B.clamp(0, 255).toInt();
    }
  }

  // ── Wave propagation (laplacian 2D wave equation) ─────────────────────────
  bool _propagate() {
    final d = _data;
    final cols = d.cols, rows = d.rows;
    final cur = d.wave;
    final next = d.next; // pre-allocated — zero alloc per frame
    final vel = d.vel;
    var active = false;

    for (int row = 1; row < rows - 1; row++) {
      for (int col = 1; col < cols - 1; col++) {
        final idx = row * cols + col;
        final lap = cur[idx - 1] +
            cur[idx + 1] +
            cur[idx - cols] +
            cur[idx + cols] -
            4 * cur[idx];
        double v = (vel[idx] + lap * _waveSpeed) * _damping;
        double w = cur[idx] + v;
        if (w.abs() > 25) {
          w *= _tension;
          v *= _tension * 0.9;
        }
        if (v.abs() < _eps && w.abs() < _eps) {
          v = 0;
          w = 0;
        }
        if (v != 0 || w != 0) active = true;
        vel[idx] = v;
        next[idx] = w;
      }
    }

    // Edge absorption
    const e = 0.3;
    for (int c = 0; c < cols; c++) {
      next[c] *= e;
      vel[c] *= e;
      next[(rows - 1) * cols + c] *= e;
      vel[(rows - 1) * cols + c] *= e;
    }
    for (int r = 0; r < rows; r++) {
      next[r * cols] *= e;
      vel[r * cols] *= e;
      next[r * cols + cols - 1] *= e;
      vel[r * cols + cols - 1] *= e;
    }

    // Swap buffers — no allocation, painter always reads d.wave
    d.wave = next;
    d.next = cur;
    return active;
  }

  // ── Ripple injection ──────────────────────────────────────────────────────
  void _addRipple(int col, int row, double strength, int radius,
      {bool ring = false}) {
    final d = _data;
    _ensureTickerRunning();
    for (int dy = -radius; dy <= radius; dy++) {
      for (int dx = -radius; dx <= radius; dx++) {
        final c = col + dx, r = row + dy;
        if (c < 0 || c >= d.cols || r < 0 || r >= d.rows) continue;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist > radius) continue;
        final idx = r * d.cols + c;
        if (ring) {
          final nd = dist / radius;
          d.wave[idx] +=
              strength * math.sin(nd * math.pi) * math.exp(-nd * 0.5);
        } else {
          final sig = radius * 0.4;
          d.wave[idx] += strength * math.exp(-(dist * dist) / (2 * sig * sig));
        }
      }
    }
  }

  // ── Ticker ────────────────────────────────────────────────────────────────
  void _onTick(Duration _) {
    if (_data.cols == 0) return;
    widget.onDebugTick?.call();

    // Pointer-driven ripples
    if (_px >= 0 && _py >= 0) {
      final col = (_px / _kCellW).floor();
      final row = (_py / _kCellH).floor();
      if (col >= 0 && col < _data.cols && row >= 0 && row < _data.rows) {
        final dx = _px - _prevPx, dy = _py - _prevPy;
        final spd = math.sqrt(dx * dx + dy * dy);
        if (_down) {
          final s = math.min(spd * _hoverStr * 3, 15.0);
          if (s > 0.2) _addRipple(col, row, s, _clickRad);
        } else {
          final s = math.min(spd * _hoverStr, 6.0);
          if (s > 0.3) _addRipple(col, row, s, _hoverRad);
        }
      }
      _prevPx = _px;
      _prevPy = _py;
    }

    final active = _propagate();
    _repaint.ping();
    if (!active && !_down) {
      _ticker.stop();
    }
  }

  void _ensureTickerRunning() {
    if (!_ticker.isActive) _ticker.start();
  }

  bool _hasWaveEnergy() {
    final d = _data;
    for (final w in d.wave) {
      if (w != 0) return true;
    }
    for (final v in d.vel) {
      if (v != 0) return true;
    }
    return false;
  }

  // ── Pointer events (Listener avoids blocking child scroll) ────────────────
  void _onPointerDown(PointerDownEvent e) {
    _showAscii(); // fade in immediately on touch
    _down = true;
    _px = e.localPosition.dx;
    _py = e.localPosition.dy;
    _prevPx = _px;
    _prevPy = _py;
    final col = (_px / _kCellW).floor();
    final row = (_py / _kCellH).floor();
    _addRipple(col, row, _clickStr, _clickRad);
    // Staggered ring expansion — realistic raindrop
    _rippleTimers.add(Timer(const Duration(milliseconds: 70), () {
      if (mounted) _addRipple(col, row, -_clickStr * 0.4, _clickRad + 3, ring: true);
      _rippleTimers.removeWhere((t) => !t.isActive);
    }));
    _rippleTimers.add(Timer(const Duration(milliseconds: 160), () {
      if (mounted) _addRipple(col, row, _clickStr * 0.2, _clickRad + 7, ring: true);
      _rippleTimers.removeWhere((t) => !t.isActive);
    }));
    _rippleTimers.add(Timer(const Duration(milliseconds: 280), () {
      if (mounted) _addRipple(col, row, -_clickStr * 0.1, _clickRad + 12, ring: true);
      _rippleTimers.removeWhere((t) => !t.isActive);
    }));
  }

  void _onPointerMove(PointerMoveEvent e) {
    _px = e.localPosition.dx;
    _py = e.localPosition.dy;
    // Keep visible while dragging — reset any pending hide timer
    _fadeOutTimer?.cancel();
    _fadeOutTimer = null;
  }

  void _onPointerUp(PointerUpEvent e) {
    _down = false;
    _px = _py = -1;
    _prevPx = _prevPy = -1;
    _scheduleHide(); // start countdown to fade out
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: LayoutBuilder(builder: (_, constraints) {
        _initGrid(constraints.biggest);
        return Stack(children: [
          // Dark base — always visible so the app never flashes white
          const ColoredBox(color: Color(0xFF05080F), child: SizedBox.expand()),

          // ASCII water layer — hidden at rest, fades in on touch, out after idle
          FadeTransition(
            opacity: _fadeCtrl,
            child: RepaintBoundary(
              child: CustomPaint(
                size: constraints.biggest,
                painter: _WaterPainter(data: _data, repaint: _repaint),
              ),
            ),
          ),

          // App content on top — always fully visible
          widget.child,
        ]);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Painter — draws ASCII chars with wave-displaced color and refraction
// ─────────────────────────────────────────────────────────────────────────────
class _WaterPainter extends CustomPainter {
  final _WaveData data;

  _WaterPainter({required this.data, required Listenable repaint})
      : super(repaint: repaint);

  // Shared immutable objects — created once
  // ASCII glyph size (canvas ParagraphStyle, not widget text).
  static const double _glyphSize = 10.0;
  static final _pStyle = ui.ParagraphStyle(
    fontFamily: 'Courier',
    fontSize: _glyphSize,
  );
  static const _pConstraints = ui.ParagraphConstraints(width: 12);

  // Per-frame paragraph cache: key = quantised (char | r5 | g5 | b5 | a4).
  // Cleared at the start of each paint call — reuse within the same frame only.
  // Reduces ParagraphBuilder allocations from ~7 K → a few hundred per frame.
  static final Map<int, ui.Paragraph> _paraCache = {};

  static int _paraKey(int r, int g, int b, double alpha, int charCode) {
    final ai = (alpha * 15).round() & 0xF;   // 4-bit alpha
    final r5 = (r >> 3) & 0x1F;              // 5-bit r
    final g5 = (g >> 3) & 0x1F;              // 5-bit g
    final b5 = (b >> 3) & 0x1F;              // 5-bit b
    return (charCode << 19) | (r5 << 14) | (g5 << 9) | (b5 << 4) | ai;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _paraCache.clear(); // reuse only within this frame

    final d = data;
    final cols = d.cols, rows = d.rows;
    final wave = d.wave; // reads latest reference set by _propagate()

    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final idx = row * cols + col;
        final w = wave[idx];

        // Surface gradient → refraction displacement
        double gx = 0, gy = 0;
        if (col > 0 && col < cols - 1) gx = wave[idx + 1] - wave[idx - 1];
        if (row > 0 && row < rows - 1) gy = wave[idx + cols] - wave[idx - cols];

        // Refracted source cell (simulates water lens)
        final sc = (col - gx * 1.4).round().clamp(0, cols - 1);
        final sr = (row - gy * 1.4).round().clamp(0, rows - 1);
        final si = sr * cols + sc;

        // Caustic lighting (converging wave front → bright spot)
        double caustic = 0;
        if (col > 0 && col < cols - 1 && row > 0 && row < rows - 1) {
          final lap = wave[idx - 1] +
              wave[idx + 1] +
              wave[idx - cols] +
              wave[idx + cols] -
              4 * w;
          caustic = math.max(0, -lap * 0.06);
        }

        // Apply brightness boost
        final wi = w.abs();
        final boost = 1 + wi * 0.04 + caustic * 2.5;
        final bR = d.cellR[si], bG = d.cellG[si], bB = d.cellB[si];
        final r = (bR * boost + caustic * 60).clamp(0, 255).toInt();
        final g = (bG * boost + caustic * 120).clamp(0, 255).toInt();
        final b = (bB * boost + caustic * 80).clamp(0, 255).toInt();

        // Alpha is PURELY wave-driven — nothing shows when wave is flat.
        // Coefficient 0.19: at peak amplitude (~32) this saturates to 1.0.
        // As the wave decays the chars fade naturally with it (no separate timer needed).
        // Caustic hotspots (converging wavefronts) get an extra brightness burst.
        final alpha = (wi * 0.19 + caustic * 3.0).clamp(0.0, 1.0);
        if (alpha < 0.04) continue;

        // Char density: denser chars where wave is tallest (surface detail)
        final lum = (wi * 0.10 + caustic * 1.8).clamp(0.0, 1.0);
        final chIdx =
            (lum * (_kChars.length - 1)).round().clamp(0, _kChars.length - 1);
        final char = _kChars[chIdx];
        if (char == ' ' && alpha < 0.05) continue;

        // Build and draw paragraph — reuse cached paragraph if quantised
        // colour + char match (avoids rebuilding identical glyphs per frame).
        final key = _paraKey(r, g, b, alpha, char.codeUnitAt(0));
        final para = _paraCache.putIfAbsent(key, () {
          return (ui.ParagraphBuilder(_pStyle)
                ..pushStyle(ui.TextStyle(
                  color: Color.fromRGBO(r, g, b, alpha),
                  fontSize: _glyphSize,
                ))
                ..addText(char))
              .build()
            ..layout(_pConstraints);
        });

        canvas.drawParagraph(
          para,
          Offset(col * _kCellW + gx * 0.5, row * _kCellH + gy * 0.35),
        );
      }
    }
  }

  // repaint listenable drives all redraws — shouldRepaint always false
  @override
  bool shouldRepaint(_WaterPainter old) => false;
}
