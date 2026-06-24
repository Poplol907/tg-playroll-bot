import 'package:flutter/material.dart';

import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_tokens.dart';
import '../../core/theme/nebula_typography.dart';

/// Presentation-only route header that participates in the page scroll flow.
class AppScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  const AppScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);

    return ConstrainedBox(
      key: const ValueKey('app-screen-header'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: NebulaTokens.sp12),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: type.displayM.copyWith(color: tokens.primaryText),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: NebulaTokens.sp4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: type.labelM.copyWith(color: tokens.mutedText),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: NebulaTokens.sp12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: trailing!,
            ),
          ],
        ],
      ),
    );
  }
}
