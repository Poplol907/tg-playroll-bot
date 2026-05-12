import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';

/// Universal frosted-glass island — the single surface primitive for all
/// cards, panels, and content wrappers.
///
/// ── Frosted glass vs plain blur ──────────────────────────────────────────
/// Plain blur: dark tint + BackdropFilter → looks like smoked glass (heavy).
/// Frosted glass: light white tint + BackdropFilter + specular sheen gradient
///   → diffuse, milky, feels like real etched glass.
///
/// Three-layer composition (bottom → top):
///   1. BackdropFilter(blur σ16) — smears the ASCII wave behind the panel
///   2. White tint base — the "frost" layer (9-14% white)
///   3. Specular sheen gradient — simulates light source hitting frosted glass:
///        top-left bright → transparent centre → subtle bottom shadow
///
/// Border trick: top/left edges are brighter than bottom/right, mimicking a
/// light source from the upper-left (same technique used in iOS glass panels).
class NebulaSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final List<BoxShadow>? glow;
  final bool dense;
  final bool frosted;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? accent;

  const NebulaSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.glow,
    this.dense = false,
    this.frosted = false,
    this.onTap,
    this.width,
    this.height,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<CosmoThemeTokens>() ?? CosmoThemeTokens.darkInternals;
    final isLight = theme.brightness == Brightness.light;
    final radius = borderRadius ?? NebulaTokens.radiusMD;
    final br = BorderRadius.circular(radius);

    // ── Border: bright top/left (specular), dim bottom/right (shadow) ───────
    final accentBorder = accent != null
        ? Border.all(color: accent!.withValues(alpha: 0.35), width: 0.8)
        : null;

    final shadows = [
      if (glow != null) ...glow!,
      // Accent: spreading paint bleed in light, focused glow in dark.
      if (accent != null) ...[
        BoxShadow(
          color: accent!.withValues(
            alpha: isLight ? 0.18 : 0.14 * tokens.glowIntensity,
          ),
          blurRadius: isLight ? 36 : 24,
          spreadRadius: isLight ? -6 : 0,
          offset: Offset.zero,
        ),
        if (isLight)
          BoxShadow(
            color: accent!.withValues(alpha: 0.08),
            blurRadius: 72,
            spreadRadius: -14,
            offset: Offset.zero,
          ),
      ],
      // Ambient lift shadow — two layers in light for soft depth.
      if (isLight) ...[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.10),
          blurRadius: 16,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 40,
          spreadRadius: -6,
          offset: const Offset(0, 10),
        ),
      ] else
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.28),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
    ];

    // ── Layer 2: frost base (tinted diffusion layer) ─────────────────────────
    // Light: strong white tint → milky frosted glass (high opacity).
    // Dark: dark background color at high opacity → matte dark glass.
    //   spaceBlack @ 78% gives a clearly solid dark panel while the blurred
    //   background still bleeds through slightly at the edges — same "matte"
    //   quality as the light version, just dark-toned.
    // Light: near-solid cool-white panel so it clearly reads against the
    // blue-gray page background. Dense surfaces (modals/forms) are fully opaque.
    // Dark: unchanged dark matte glass.
    final frostBase = dense
        ? (isLight
            ? const Color(0xFFF8FAFE)   // 100% — solid white for modals
            : NebulaColors.depthMid.withValues(alpha: 0.94))
        : (isLight
            ? const Color(0xF2FFFFFF)   // 95% opaque white — clearly visible panel
            : NebulaColors.spaceBlack.withValues(alpha: 0.90));

    // ── Layer 3: specular sheen gradient (light from top-left) ──────────────
    // Bright corner → transparent → dim shadow corner.
    // Light theme uses a subtle gray sheen instead of white-on-white.
    // Light: subtle white-to-transparent highlight (top-left) + faint shadow
    // bottom — creates a pressed-glass highlight without adding haze over content.
    final sheenGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isLight
          ? [
              Colors.white.withValues(alpha: 0.80),
              Colors.white.withValues(alpha: 0.10),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.03),
            ]
          : [
              Colors.white.withValues(alpha: dense ? 0.13 : 0.09),
              Colors.white.withValues(alpha: 0.03),
              Colors.transparent,
              Colors.black.withValues(alpha: 0.08),
            ],
      stops: const [0.0, 0.22, 0.55, 1.0],
    );

    // Outer: frost base + specular border + ambient shadow
    final inner = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: frostBase,
        borderRadius: br,
        border: accentBorder,
        boxShadow: shadows,
      ),
      // Inner: specular sheen + warm pearl overlay + content
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: sheenGradient,
              borderRadius: br,
            ),
            padding: padding ?? const EdgeInsets.all(NebulaTokens.sp20),
            // Propagate theme-correct default text colour to all Text children
            // that don't set an explicit colour.
            child: DefaultTextStyle.merge(
              style: TextStyle(color: tokens.primaryText),
              child: child,
            ),
          ),
          if (accent == null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpecularBorderPainter(radius: radius, isLight: isLight),
                ),
              ),
            ),
        ],
      ),
    );

    final clipped = ClipRRect(
      borderRadius: br,
      child: frosted
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: inner,
            )
          : inner,
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: clipped,
      );
    }
    return clipped;
  }
}

class _SpecularBorderPainter extends CustomPainter {
  final double radius;
  final bool isLight;

  const _SpecularBorderPainter({required this.radius, required this.isLight});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final rrect =
        RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius));
    final path = Path()..addRRect(rrect);

    void drawEdge(Rect shaderRect, List<Color> colors) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(colors: colors).createShader(shaderRect);
      canvas.drawPath(path, paint);
    }

    if (isLight) {
      // Light theme: dark hairline on top, lighter bottom — elevation cue on white
      drawEdge(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.55),
        [
          Colors.black.withValues(alpha: 0.12),
          Colors.black.withValues(alpha: 0.06),
          Colors.transparent,
        ],
      );
      drawEdge(
        Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
        [
          Colors.transparent,
          Colors.black.withValues(alpha: 0.04),
        ],
      );
    } else {
      // Dark theme: bright specular top, dim specular bottom
      drawEdge(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.55),
        [
          Colors.white.withValues(alpha: 0.22),
          Colors.white.withValues(alpha: 0.12),
          Colors.white.withValues(alpha: 0.04),
        ],
      );
      drawEdge(
        Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
        [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.05),
        ],
      );
    }
  }

  @override
  bool shouldRepaint(_SpecularBorderPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.isLight != isLight;
}
