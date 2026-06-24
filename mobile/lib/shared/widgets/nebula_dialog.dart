import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_tokens.dart';
import '../../core/theme/nebula_typography.dart';
import 'nebula_surface.dart';

class NebulaDialog extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final Color accent;
  final String cancelLabel;
  final String confirmLabel;
  final bool destructive;

  const NebulaDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.accent = NebulaColors.stellarBlue,
    this.cancelLabel = 'Отмена',
    this.confirmLabel = 'ОК',
    this.destructive = false,
  });

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String cancelLabel = 'Отмена',
    String confirmLabel = 'ОК',
    bool destructive = false,
    IconData? icon,
  }) async {
    final accent =
        destructive ? NebulaColors.errorRose : NebulaColors.stellarBlue;
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: NebulaAlpha.strong),
          builder: (ctx) => NebulaDialog(
            title: title,
            message: message,
            icon: icon ??
                (destructive
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline_rounded),
            accent: accent,
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            destructive: destructive,
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final confirmColor = destructive ? NebulaColors.errorRose : accent;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: NebulaSurface(
          dense: true,
          accent: accent,
          padding: const EdgeInsets.all(NebulaTokens.sp24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withValues(alpha: NebulaAlpha.surface),
                        border: Border.all(
                          color: accent.withValues(alpha: NebulaAlpha.accent),
                        ),
                        boxShadow: NebulaTokens.glowSoft(accent),
                      ),
                      child: Icon(icon, color: accent, size: 21),
                    ),
                    const SizedBox(width: NebulaTokens.sp12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: NebulaTypography.of(context).titleM.copyWith(
                                  color: tokens.primaryText,
                                ),
                          ),
                          const SizedBox(height: NebulaTokens.sp8),
                          Flexible(
                            child: SingleChildScrollView(
                              child: Text(
                                message,
                                style:
                                    NebulaTypography.of(context).bodyM.copyWith(
                                          color: tokens.secondaryText,
                                        ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NebulaTokens.sp24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _NebulaDialogAction(
                    label: cancelLabel,
                    color: NebulaColors.dimText,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: NebulaTokens.sp8),
                  _NebulaDialogAction(
                    label: confirmLabel,
                    color: confirmColor,
                    filled: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NebulaDialogAction extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool filled;

  const _NebulaDialogAction({
    required this.label,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: NebulaRadii.controlBorder,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 82),
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: NebulaTokens.sp16,
              vertical: NebulaTokens.sp12,
            ),
            decoration: BoxDecoration(
              color: filled
                  ? color.withValues(alpha: NebulaAlpha.surface)
                  : Colors.transparent,
              borderRadius: NebulaRadii.controlBorder,
              border: Border.all(
                color: filled
                    ? color.withValues(alpha: NebulaAlpha.accent)
                    : NebulaColors.surfaceBorder,
              ),
            ),
            child: Center(
              child: Builder(builder: (ctx) {
                final tokens = Theme.of(ctx).extension<CosmoThemeTokens>() ??
                    CosmoThemeTokens.darkInternals;
                return Text(
                  label,
                  style: NebulaTypography.of(ctx).bodyM.copyWith(
                        color: filled ? color : tokens.mutedText,
                        fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
                      ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
