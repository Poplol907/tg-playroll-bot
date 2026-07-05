import 'package:flutter/material.dart';

import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_tokens.dart';
import '../../core/theme/nebula_typography.dart';

/// Единый слот ошибки формы в шитах.
///
/// Правило одно на всё приложение: баннер живёт СТРОГО над submit-кнопкой,
/// так что ошибка всегда выскакивает в одном и том же месте, каким бы ни
/// был шит. null → схлопнут; появление — AnimatedSize без прыжка макета.
class SheetErrorBanner extends StatelessWidget {
  final String? error;

  const SheetErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return AnimatedSize(
      duration: NebulaTokens.feedback,
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: error == null
          ? const SizedBox(width: double.infinity)
          : Container(
              key: const ValueKey('sheet-error-banner'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: NebulaTokens.sp12),
              padding: const EdgeInsets.symmetric(
                horizontal: NebulaTokens.sp12,
                vertical: NebulaTokens.sp8,
              ),
              decoration: BoxDecoration(
                color: tokens.error.withValues(alpha: NebulaAlpha.mist),
                borderRadius: NebulaRadii.controlBorder,
                border: Border.all(
                  color: tokens.error.withValues(alpha: NebulaAlpha.accent),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      size: 16, color: tokens.error),
                  const SizedBox(width: NebulaTokens.sp8),
                  Expanded(
                    child: Text(
                      error!,
                      style: type.labelM.copyWith(color: tokens.error),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
