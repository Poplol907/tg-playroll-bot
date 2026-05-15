import 'package:flutter/material.dart';

import '../../../core/theme/cosmo_theme_tokens.dart';
import '../../../core/theme/nebula_component_styles.dart';
import '../../../core/theme/nebula_semantic.dart';
import '../../../core/theme/nebula_typography.dart';

/// A tappable "icon + label + chevron" row — used in settings, profile
/// dialogs, and side menus. Picks up the active intent role for the
/// icon color while keeping the label in the regular text color.
class ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final SemanticIntent intent;
  final VoidCallback onTap;
  final bool destructive;
  final ActionRowStyle? styleOverride;

  const ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.intent = SemanticIntent.primary,
    this.destructive = false,
    this.styleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleOverride ?? NebulaComponentStyles.of(context).actionRow;
    final semantic = NebulaSemantic.of(context);
    final role = semantic.byIntent(destructive ? SemanticIntent.danger : intent);
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    final labelColor = destructive ? role.contrast : tokens.primaryText;

    return Material(
      color: Colors.transparent,
      borderRadius: style.borderRadius,
      child: InkWell(
        borderRadius: style.borderRadius,
        onTap: onTap,
        child: Padding(
          padding: style.padding,
          child: Row(
            children: [
              Container(
                width: style.iconBoxSize,
                height: style.iconBoxSize,
                decoration: BoxDecoration(
                  color: role.tint,
                  shape: BoxShape.circle,
                  border: Border.all(color: role.border, width: 0.6),
                ),
                child: Icon(icon, color: role.contrast, size: style.iconSize),
              ),
              SizedBox(width: style.iconGap),
              Expanded(
                child: Text(
                  label,
                  style: type.titleS.copyWith(color: labelColor),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: tokens.mutedText,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
