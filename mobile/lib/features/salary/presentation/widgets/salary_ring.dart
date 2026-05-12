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
        return ('@', NebulaColors.successMint, (0.95 + breathe * 0.05) * scale);
      }
      final sh = math.sin(i * 0.71);
      final c = sh > 0.3 ? '#' : (sh > -0.3 ? '*' : '+');
      return (c, NebulaColors.successMint, (0.85 + breathe * 0.15) * scale);
    } else if (frac < earnedFrac + pendingFrac) {
      final sh = math.sin(i * 0.85);
      return (sh > 0.2 ? '+' : '~', NebulaColors.warningAmber, 0.80 * scale);
    } else {
      return ('.', Colors.white, 0.18 * scale);
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

    // Track — very dim white halo so the empty arc reads without becoming solid.
    canvas.drawCircle(
      Offset(cx, cy),
      midR,
      Paint()
        ..color =
            Colors.white.withValues(alpha: SalaryRingVisualProfile.trackAlpha)
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
          ..color = NebulaColors.successMint.withValues(
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
          ..color = NebulaColors.warningAmber
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
          ..color =
              NebulaColors.successMint.withValues(alpha: 0.70 + breathe * 0.30)
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
