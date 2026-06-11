part of '../screens/salary_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Progress ring painter — soft halo + ASCII texture body
//
//  Two-pass rendering:
//    Pass 1 (halo/glow)   — very soft track and blurred segment bloom only.
//    Pass 2 (ASCII bands) — 5 concentric ASCII rings forming the visible body.
//                           Inner/outer fringes add depth gradient.
// ─────────────────────────────────────────────────────────────────────────────

class SalaryRingVisualProfile {
  const SalaryRingVisualProfile._();

  static const double trackAlpha = 0.06;
  static const double earnedBloomAlpha = 0.18;
  static const double earnedBloomBreatheAlpha = 0.04;
  static const double earnedSolidCoreAlpha = 0;
  static const double pendingBloomAlpha = 0.14;
  static const double pendingSolidCoreAlpha = 0;
  static const bool enableAmbientBreathing = false;
  static const double staticBreatheValue = 0.5;
}

class _RingPainter extends CustomPainter {
  final double earnedFrac;
  final double pendingFrac;
  final double breathe;

  // Dark-theme-only painter (light renders _LiquidBubblePainter instead),
  // so the signature mint/amber/white palette stays hardcoded here.
  static const Color success = NebulaColors.successMint;
  static const Color warning = NebulaColors.warningAmber;
  static const Color ink = Colors.white;

  static final _pLg = ui.ParagraphStyle(fontFamily: 'Courier', fontSize: 14.0);
  static final _pMd = ui.ParagraphStyle(fontFamily: 'Courier', fontSize: 11.0);
  static final _pSm = ui.ParagraphStyle(fontFamily: 'Courier', fontSize: 9.0);
  static const _pcLg = ui.ParagraphConstraints(width: 17);
  static const _pcMd = ui.ParagraphConstraints(width: 14);
  static const _pcSm = ui.ParagraphConstraints(width: 11);

  _RingPainter({
    required this.earnedFrac,
    required this.pendingFrac,
    this.breathe = 0.0,
  });

  // ── char selection ────────────────────────────────────────────────────────
  (String, Color, double) _cell(double frac, int i, double scale) {
    if (frac < earnedFrac) {
      final isLead = earnedFrac > 0.02 && frac > earnedFrac - 2.5 / 100;
      if (isLead) {
        return ('@', success, (0.95 + breathe * 0.05) * scale);
      }
      final sh = math.sin(i * 0.71);
      final c = sh > 0.3 ? '#' : (sh > -0.3 ? '*' : '+');
      return (c, success, (0.85 + breathe * 0.15) * scale);
    } else if (frac < earnedFrac + pendingFrac) {
      final sh = math.sin(i * 0.85);
      return (sh > 0.2 ? '+' : '~', warning, 0.80 * scale);
    } else {
      return ('.', ink, 0.18 * scale);
    }
  }

  // ── single ASCII ring ─────────────────────────────────────────────────────
  void _asciiRing(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double spacing,
    double scale,
    ui.ParagraphStyle ps,
    ui.ParagraphConstraints pc,
    double fontSize,
  ) {
    final n = (2 * math.pi * r / spacing).round();
    for (int i = 0; i < n; i++) {
      final frac = i / n;
      final angle = -math.pi / 2 + frac * 2 * math.pi;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      final (char, color, alpha) = _cell(frac, i, scale);
      if (alpha < 0.04) continue;
      final para = (ui.ParagraphBuilder(ps)
            ..pushStyle(ui.TextStyle(
              color: color.withValues(alpha: alpha.clamp(0.0, 1.0)),
              fontSize: fontSize,
            ))
            ..addText(char))
          .build()
        ..layout(pc);
      canvas.drawParagraph(
        para,
        Offset(x - fontSize * 0.43, y - fontSize * 0.55),
      );
    }
  }

  // ── paint ─────────────────────────────────────────────────────────────────
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final midR = (size.width / 2) - 22;
    const sw = 32.0; // halo stroke width; ASCII bands form the visible body
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: midR);
    const startA = -math.pi / 2;

    // ══ PASS 1 — soft halo/glow under the ASCII body ════════════════════════

    // Track — very dim ink halo so the empty arc reads without becoming solid.
    canvas.drawCircle(
      Offset(cx, cy),
      midR,
      Paint()
        ..color = ink.withValues(alpha: SalaryRingVisualProfile.trackAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw,
    );

    // Earned — blurred bloom only; ASCII glyphs are the ring body.
    if (earnedFrac > 0) {
      final sweep = 2 * math.pi * earnedFrac;
      canvas.drawArc(
        rect,
        startA,
        sweep,
        false,
        Paint()
          ..color = success.withValues(
            alpha: SalaryRingVisualProfile.earnedBloomAlpha +
                breathe * SalaryRingVisualProfile.earnedBloomBreatheAlpha,
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw + 10
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Pending — blurred bloom only; ASCII glyphs carry the state/readability.
    if (pendingFrac > 0) {
      final pStart = startA + 2 * math.pi * earnedFrac;
      final sweep = 2 * math.pi * pendingFrac;
      canvas.drawArc(
        rect,
        pStart,
        sweep,
        false,
        Paint()
          ..color = warning
              .withValues(alpha: SalaryRingVisualProfile.pendingBloomAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw + 8
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Leading-edge bright dot
    if (earnedFrac > 0.01) {
      final a = startA + 2 * math.pi * earnedFrac;
      final dot = Offset(cx + midR * math.cos(a), cy + midR * math.sin(a));
      canvas.drawCircle(
        dot,
        9,
        Paint()
          ..color = success.withValues(alpha: 0.70 + breathe * 0.30)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(dot, 4, Paint()..color = Colors.white);
    }

    // ══ PASS 2 — ASCII texture bands (5 rings, gradient depth) ═════════════
    _asciiRing(canvas, cx, cy, midR - 20, 7.5, 0.55, _pSm, _pcSm, 9.0);
    _asciiRing(canvas, cx, cy, midR - 10, 8.8, 0.80, _pMd, _pcMd, 11.0);
    _asciiRing(canvas, cx, cy, midR, 9.5, 1.00, _pLg, _pcLg, 14.0);
    _asciiRing(canvas, cx, cy, midR + 10, 8.8, 0.80, _pMd, _pcMd, 11.0);
    _asciiRing(canvas, cx, cy, midR + 20, 7.5, 0.55, _pSm, _pcSm, 9.0);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.earnedFrac != earnedFrac ||
      old.pendingFrac != pendingFrac ||
      old.breathe != breathe;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Liquid bubble painter — light theme progress visual
//
//  A glass bubble (vial) filled with translucent liquid: the liquid level IS
//  the salary progress. Two layers — earned (green) below, pending (amber)
//  floating on top — each with a gently waving surface. A few bubbles rise
//  through the liquid for the "circulating" feel. Liquid stays translucent so
//  the % label in the centre remains readable through it.
// ─────────────────────────────────────────────────────────────────────────────

class _LiquidBubblePainter extends CustomPainter {
  final double earnedFrac;
  final double pendingFrac;

  /// 0..1 looping phase of the circulation animation.
  final double wave;

  final Color success;
  final Color warning;
  final Color ink;

  static const double _bodyAlpha = 0.20;
  static const double _crestAlpha = 0.85;
  static const double _shellAlpha = 0.12;

  _LiquidBubblePainter({
    required this.earnedFrac,
    required this.pendingFrac,
    required this.wave,
    required this.success,
    required this.warning,
    required this.ink,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width / 2) - 26;
    final center = Offset(cx, cy);
    final circle = Path()..addOval(Rect.fromCircle(center: center, radius: r));

    final earned = earnedFrac.clamp(0.0, 1.0);
    final total = (earnedFrac + pendingFrac).clamp(0.0, 1.0);
    double levelY(double frac) => cy + r - 2 * r * frac;

    // ── Liquid (clipped to the bubble) ─────────────────────────────────────
    canvas.save();
    canvas.clipPath(circle);

    // Pending (amber) — fills from its level down; the green layer painted
    // after will cover everything below the earned level.
    if (total > earned + 0.005) {
      _liquidLayer(
        canvas,
        cx: cx,
        r: r,
        bottom: cy + r,
        surfaceY: levelY(total),
        color: warning,
        amp: 4.5,
        phase: 2.1,
        dir: -1,
      );
    }
    if (earned > 0.005) {
      _liquidLayer(
        canvas,
        cx: cx,
        r: r,
        bottom: cy + r,
        surfaceY: levelY(earned),
        color: success,
        amp: 5.5,
        phase: 0.0,
        dir: 1,
      );

      // Rising bubbles — the "circulation". Deterministic phases, looping.
      final liquidTop = levelY(earned);
      final liquidH = (cy + r) - liquidTop;
      if (liquidH > 18) {
        for (var k = 0; k < 5; k++) {
          final prog = (wave * (0.6 + 0.2 * (k % 3)) + k * 0.37) % 1.0;
          final y = (cy + r - 6) - prog * (liquidH - 14);
          final x = cx +
              math.sin(prog * math.pi * 3 + k * 2.1) * r * (0.18 + 0.09 * k);
          final fade = (1.0 - prog) * 0.30 + 0.06;
          canvas.drawCircle(
            Offset(x, y),
            1.8 + (k % 3),
            Paint()..color = success.withValues(alpha: fade),
          );
        }
      }
    }

    canvas.restore();

    // ── Glass shell ────────────────────────────────────────────────────────
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = ink.withValues(alpha: _shellAlpha),
    );
    // Specular highlight — short arc top-left, softly blurred: glass, not wire.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r - 5),
      -math.pi * 0.80,
      math.pi * 0.34,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
        ..color = Colors.white.withValues(alpha: 0.55),
    );
  }

  /// One liquid layer: translucent body fill + brighter waving crest line.
  void _liquidLayer(
    Canvas canvas, {
    required double cx,
    required double r,
    required double bottom,
    required double surfaceY,
    required Color color,
    required double amp,
    required double phase,
    required int dir,
  }) {
    final left = cx - r;
    final width = 2 * r;
    const n = 28;

    final crest = Path()..moveTo(left, _waveY(surfaceY, 0, amp, phase, dir));
    for (var i = 1; i <= n; i++) {
      final f = i / n;
      crest.lineTo(left + width * f, _waveY(surfaceY, f, amp, phase, dir));
    }

    final body = Path.from(crest)
      ..lineTo(left + width, bottom)
      ..lineTo(left, bottom)
      ..close();

    canvas.drawPath(
      body,
      Paint()..color = color.withValues(alpha: _bodyAlpha),
    );
    canvas.drawPath(
      crest,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: _crestAlpha),
    );
  }

  double _waveY(double base, double f, double amp, double phase, int dir) =>
      base + amp * math.sin(f * math.pi * 2 * 1.6 + wave * math.pi * 2 * dir + phase);

  @override
  bool shouldRepaint(_LiquidBubblePainter old) =>
      old.earnedFrac != earnedFrac ||
      old.pendingFrac != pendingFrac ||
      old.wave != wave ||
      old.success != success ||
      old.warning != warning ||
      old.ink != ink;
}
