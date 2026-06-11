import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';
import 'nebula_surface.dart';

enum NebulaSnackTone { success, warning, error, info }

void showNebulaSnackBar(
  BuildContext context, {
  required String title,
  String? message,
  NebulaSnackTone tone = NebulaSnackTone.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final (accent, icon) = switch (tone) {
    NebulaSnackTone.success => (
        NebulaColors.successMint,
        Icons.check_circle_rounded,
      ),
    NebulaSnackTone.warning => (
        NebulaColors.warningAmber,
        Icons.warning_amber_rounded,
      ),
    NebulaSnackTone.error => (
        NebulaColors.errorRose,
        Icons.error_outline_rounded,
      ),
    NebulaSnackTone.info => (
        NebulaColors.stellarBlue,
        Icons.info_outline_rounded,
      ),
  };

  final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
      CosmoThemeTokens.darkInternals;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      content: NebulaSurface(
        dense: true,
        accent: accent,
        borderRadius: NebulaTokens.radiusMD,
        padding: const EdgeInsets.symmetric(
          horizontal: NebulaTokens.sp16,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: NebulaTokens.sp12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: tokens.primaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (message != null && message.isNotEmpty) ...[
                    const SizedBox(height: NebulaTokens.sp2),
                    Text(
                      message,
                      style: TextStyle(
                        color: tokens.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
