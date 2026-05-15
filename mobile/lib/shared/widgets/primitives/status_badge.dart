import 'package:flutter/material.dart';

import '../../../core/theme/nebula_component_styles.dart';
import '../../../core/theme/nebula_semantic.dart';
import '../../../core/theme/nebula_typography.dart';

/// Tiny pill that communicates state at a glance.
///
/// Usage:
///   StatusBadge(label: 'TEACHER', intent: SemanticIntent.info)
///
/// Everything visual (sizes, padding, colors, font) flows from theme
/// tokens. The widget itself owns nothing.
class StatusBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final SemanticIntent intent;
  final BadgeStyle? styleOverride;

  const StatusBadge({
    super.key,
    required this.label,
    this.icon,
    this.intent = SemanticIntent.neutral,
    this.styleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleOverride ?? NebulaComponentStyles.of(context).badge;
    final role = NebulaSemantic.of(context).byIntent(intent);
    final type = NebulaTypography.of(context);

    return Container(
      height: style.height,
      padding: style.padding,
      decoration: BoxDecoration(
        color: role.tint,
        borderRadius: style.borderRadius,
        border: Border.all(color: role.border, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: role.contrast, size: style.iconSize),
            SizedBox(width: style.iconGap),
          ],
          Text(
            label,
            style: type.labelS.copyWith(
              color: role.contrast,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
