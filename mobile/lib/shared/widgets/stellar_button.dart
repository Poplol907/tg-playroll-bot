import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_surface_profile.dart';
import '../../core/theme/nebula_tokens.dart';

/// Primary action button using Nebula Material.
/// Replaces [CosmoButton] — luminous tint fill + radial glow, no solid fill.
///
/// Key differences from CosmoButton:
/// - Fill is translucent accent (15%) not solid color
/// - Glow is radial (Offset.zero) not directional (Offset(0,6))
/// - Glow intensifies on press via AnimationController
class StellarButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color? color;
  final double? width;
  final IconData? icon;

  const StellarButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.color,
    this.width,
    this.icon,
  });

  @override
  State<StellarButton> createState() => _StellarButtonState();
}

class _StellarButtonState extends State<StellarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _press;
  late Animation<double> _scale;
  late Animation<double> _glowProgress;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: NebulaTokens.tapFast,
      reverseDuration: NebulaTokens.tapRelease,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
    _glowProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<CosmoThemeTokens>() ?? CosmoThemeTokens.darkInternals;
    final isLight = theme.brightness == Brightness.light;
    final accent = widget.color ?? tokens.primaryAccent;
    final disabled = widget.onPressed == null || widget.loading;
    final surface = NebulaSurfaceProfile.panel.resolve(context, accent: accent);

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _press.forward(),
      onTapUp: disabled ? null : (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) {
          final g = _glowProgress.value;
          final glow = tokens.glowIntensity;
          final borderAlpha = disabled
              ? 0.10
              : isLight
                  ? 0.14 + g * 0.10
                  : 0.25 + g * 0.35;
          final foreground =
              isLight ? tokens.primaryText : NebulaColors.softWhite;
          final disabledForeground = foreground.withValues(alpha: 0.5);
          final textShadows = isLight || disabled
              ? null
              : [
                  Shadow(
                    color: accent.withValues(alpha: (0.6 + g * 0.4) * glow),
                    blurRadius: 6 + g * 6,
                  ),
                  Shadow(
                    color: accent.withValues(alpha: (0.3 + g * 0.3) * glow),
                    blurRadius: 16 + g * 12,
                  ),
                ];
          return Transform.scale(
            scale: disabled ? 1.0 : _scale.value,
            child: Container(
              key: const ValueKey('stellar-button-surface'),
              width: widget.width ?? double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: surface.fill,
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(
                      alpha: isLight ? 0.08 + g * 0.02 : 0.12 + g * 0.03,
                    ),
                    surface.fill,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                // Control geometry, NOT the panel profile's 24: a button is a
                // control and must rhyme with the inputs sitting next to it
                // in every form (NebulaInput/NebulaTextButton = control 12).
                borderRadius: NebulaRadii.controlBorder,
                border: Border.all(
                  color: accent.withValues(alpha: borderAlpha),
                  width: surface.borderWidth,
                ),
              ),
              child: Center(
                child: widget.loading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: accent,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: disabled
                                  ? accent.withValues(alpha: 0.5)
                                  : accent,
                              size: 20,
                              shadows: textShadows,
                            ),
                            const SizedBox(width: NebulaTokens.sp8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: disabled ? disabledForeground : foreground,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              shadows: textShadows,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
