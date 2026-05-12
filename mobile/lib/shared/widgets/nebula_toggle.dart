import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';

class NebulaToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final double width;
  final double height;

  const NebulaToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.width = 56.0,
    this.height = 32.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<CosmoThemeTokens>() ?? CosmoThemeTokens.darkInternals;
    final isLight = theme.brightness == Brightness.light;
    final effectiveActiveColor = activeColor ?? tokens.focusAccent;
    final visualHeight = height;
    final tapHeight = height < 44 ? 44.0 : height;
    final verticalInset = (tapHeight - visualHeight) / 2;
    final thumbSize = visualHeight - 8.0; // 4px padding on each side

    // Spline-like spring animation curve
    const duration = Duration(milliseconds: 450);
    const curve = Curves.easeOutBack;

    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: width,
        height: tapHeight,
        child: Stack(
          children: [
            // Track — no BackdropFilter (expensive with animated background)
            Positioned(
              left: 0,
              right: 0,
              top: verticalInset,
              height: visualHeight,
              child: AnimatedContainer(
                duration: duration,
                curve: curve,
                decoration: BoxDecoration(
                  color: value
                      ? effectiveActiveColor.withValues(
                          alpha: isLight ? 0.10 : 0.18,
                        )
                      : isLight
                          ? tokens.surface
                          : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(visualHeight / 2),
                  border: Border.all(
                    color: value
                        ? effectiveActiveColor.withValues(
                            alpha: isLight ? 0.24 : 0.35,
                          )
                        : isLight
                            ? tokens.surfaceBorder
                            : Colors.white.withValues(alpha: 0.14),
                    width: 1.0,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.20),
                      if (isLight) Colors.white.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                    stops: isLight ? const [0.0, 0.3, 1.0] : const [0.0, 0.4],
                  ),
                ),
              ),
            ),

            // Thumb
            AnimatedPositioned(
              duration: duration,
              curve: curve,
              top: verticalInset + 4.0,
              left: value ? width - thumbSize - 4.0 : 4.0,
              child: AnimatedContainer(
                duration: duration,
                curve: curve,
                width: thumbSize,
                height: thumbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? effectiveActiveColor
                      : isLight
                          ? tokens.denseSurface
                          : NebulaColors.softWhite,
                  boxShadow: value
                      ? (isLight
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8.0,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : [
                              // Outer glow
                              BoxShadow(
                                color: effectiveActiveColor.withValues(
                                  alpha: 0.4 * tokens.glowIntensity,
                                ),
                                blurRadius: 12.0,
                                spreadRadius: 2.0,
                              ),
                              // Drop shadow
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 2.0,
                                offset: Offset.zero,
                              ),
                            ])
                      : [
                          // Inactive drop shadow
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4.0,
                            offset: Offset.zero,
                          ),
                        ],
                ),
                // Inner highlight for the 3D thumb effect
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.15),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
