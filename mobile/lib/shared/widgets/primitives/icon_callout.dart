import 'package:flutter/material.dart';

import '../../../core/theme/cosmo_theme_tokens.dart';
import '../../../core/theme/nebula_component_styles.dart';
import '../../../core/theme/nebula_semantic.dart';
import '../../../core/theme/nebula_typography.dart';

/// "Icon-puck + title + subtitle + trailing" row. Used everywhere the
/// design calls for an iconified list item: settings rows, action rows,
/// teacher tiles, lesson summaries.
///
/// The widget renders ONLY layout. Colors come from `NebulaSemantic`,
/// sizes from `NebulaComponentStyles.callout`, fonts from
/// `NebulaTypography`. Change any of those — every callout updates.
class IconCallout extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final SemanticIntent intent;
  final VoidCallback? onTap;
  final IconCalloutStyle? styleOverride;

  const IconCallout({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.intent = SemanticIntent.primary,
    this.onTap,
    this.styleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleOverride ?? NebulaComponentStyles.of(context).callout;
    final role = NebulaSemantic.of(context).byIntent(intent);
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    final content = Padding(
      padding: style.padding,
      child: Row(
        children: [
          Container(
            width: style.iconBoxSize,
            height: style.iconBoxSize,
            decoration: BoxDecoration(
              color: role.tint,
              shape: BoxShape.circle,
              border: Border.all(color: role.border, width: 0.8),
            ),
            child: Icon(icon, color: role.contrast, size: style.iconSize),
          ),
          SizedBox(width: style.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: type.titleS.copyWith(color: tokens.primaryText),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: type.labelS.copyWith(color: tokens.mutedText),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: style.borderRadius,
      child: InkWell(
        borderRadius: style.borderRadius,
        onTap: onTap,
        child: content,
      ),
    );
  }
}
