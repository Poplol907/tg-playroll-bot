import 'package:flutter/material.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_tokens.dart';

class NebulaTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final IconData? icon;
  final bool filled;
  final bool compact;

  const NebulaTextButton({
    super.key,
    required this.label,
    this.onPressed,
    this.color = NebulaColors.stellarBlue,
    this.icon,
    this.filled = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? color : NebulaColors.ghostText;
    final horizontal = compact ? NebulaTokens.sp12 : NebulaTokens.sp16;
    final vertical = compact ? NebulaTokens.sp8 : NebulaTokens.sp12;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: AnimatedOpacity(
        duration: NebulaTokens.tapFast,
        opacity: enabled ? 1 : 0.55,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: horizontal,
            vertical: vertical,
          ),
          decoration: BoxDecoration(
            color: filled
                ? color.withValues(alpha: enabled ? 0.08 : 0.04)
                : Colors.transparent,
            borderRadius: NebulaRadii.controlBorder,
            border: filled
                ? Border.all(
                    color: color.withValues(alpha: enabled ? 0.25 : 0.10),
                    width: 0.8,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: foreground, size: compact ? 14 : 16),
                const SizedBox(width: NebulaTokens.sp8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
