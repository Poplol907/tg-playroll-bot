import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_surface_profile.dart';
import '../../core/theme/nebula_tokens.dart';

/// Canonical Nebula surface primitive for cards, panels, and content wrappers.
///
/// Default surfaces are cheap: no BackdropFilter, no animated blur, just a
/// theme-aware fill, border, specular edge, and optional static accent shadow.
/// Set [frosted] only for small, explicitly justified areas.
class NebulaSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final NebulaRadiusRole? radiusRole;
  final BoxShape shape;
  final List<BoxShadow>? glow;
  final NebulaSurfaceProfile? profile;
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
    this.radiusRole,
    this.shape = BoxShape.rectangle,
    this.glow,
    this.profile,
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
    final selectedProfile = profile ??
        (dense ? NebulaSurfaceProfile.panel : NebulaSurfaceProfile.card);
    final surfaceStyle = selectedProfile.resolve(context, accent: accent);
    final isFrosted =
        frosted || selectedProfile == NebulaSurfaceProfile.frostedSmall;
    final blurSigma = selectedProfile == NebulaSurfaceProfile.frostedSmall
        ? surfaceStyle.blurSigma
        : (frosted ? NebulaTokens.frostedBlurSigma : NebulaTokens.blurDense);
    final radius = radiusRole?.value ?? surfaceStyle.radius;
    final isCircle = shape == BoxShape.circle;
    final br = isCircle ? null : BorderRadius.circular(radius);

    // Frosted surfaces drop fill opacity so the blurred backdrop reads as
    // a frosted pane. Without this the blur hides behind a ~90% opaque fill
    // and the glass effect is invisible. Single source for the frosted look.
    final fill = isFrosted
        ? surfaceStyle.fill.withValues(
            alpha: surfaceStyle.fill.a * NebulaTokens.frostedFillFactor,
          )
        : surfaceStyle.fill;

    final shadows = [
      ...surfaceStyle.shadows,
      if (glow != null) ...glow!,
    ];

    // Outer: profile fill + border + ambient shadow.
    final inner = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fill,
        shape: shape,
        borderRadius: br,
        border: Border.all(
          color: surfaceStyle.border,
          width: surfaceStyle.borderWidth,
        ),
        boxShadow: shadows,
      ),
      // Inner: profile sheen + content.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: surfaceStyle.sheen,
              shape: shape,
              borderRadius: br,
            ),
            padding: padding ?? surfaceStyle.padding,
            // Propagate theme-correct default text colour to all Text children
            // that don't set an explicit colour.
            child: DefaultTextStyle.merge(
              style: TextStyle(color: tokens.primaryText),
              child: child,
            ),
          ),
          if (surfaceStyle.paintSpecularBorder && accent == null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpecularBorderPainter(
                    radius: radius,
                    shape: shape,
                    isLight: isLight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    final filtered = isFrosted
        ? BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: blurSigma,
              sigmaY: blurSigma,
            ),
            child: inner,
          )
        : inner;
    final clipped = isCircle
        ? ClipOval(child: filtered)
        : ClipRRect(borderRadius: br!, child: filtered);

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
  final BoxShape shape;
  final bool isLight;

  const _SpecularBorderPainter({
    required this.radius,
    required this.shape,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final path = Path();
    if (shape == BoxShape.circle) {
      path.addOval(rect.deflate(0.5));
    } else {
      final rrect =
          RRect.fromRectAndRadius(rect.deflate(0.5), Radius.circular(radius));
      path.addRRect(rrect);
    }

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
          Colors.black.withValues(alpha: NebulaAlpha.surface),
          Colors.black.withValues(alpha: NebulaAlpha.mist),
          Colors.transparent,
        ],
      );
      drawEdge(
        Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
        [
          Colors.transparent,
          Colors.black.withValues(alpha: NebulaAlpha.whisper),
        ],
      );
    } else {
      // Dark theme: bright specular top, dim specular bottom
      drawEdge(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.55),
        [
          Colors.white.withValues(alpha: NebulaAlpha.border),
          Colors.white.withValues(alpha: NebulaAlpha.surface),
          Colors.white.withValues(alpha: NebulaAlpha.whisper),
        ],
      );
      drawEdge(
        Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.55),
        [
          Colors.transparent,
          Colors.white.withValues(alpha: NebulaAlpha.whisper),
        ],
      );
    }
  }

  @override
  bool shouldRepaint(_SpecularBorderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.shape != shape ||
      oldDelegate.isLight != isLight;
}
