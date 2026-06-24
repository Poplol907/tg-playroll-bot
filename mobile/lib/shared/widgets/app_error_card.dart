import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_typography.dart';
import 'nebula_surface.dart';
import 'nebula_text_button.dart';

/// Empty state — когда данные загрузились, но список пустой.
/// Показывает нейтральную иконку без ошибки.
class AppEmptyState extends StatelessWidget {
  final String message;
  final String? subtitle;
  final IconData icon;

  const AppEmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: tokens.mutedText, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: type.titleS.copyWith(color: tokens.mutedText),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: type.bodyS.copyWith(color: tokens.mutedText),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-width error state shown when a data provider fails to load.
/// Style matches the salary screen error card.
class AppErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  /// Если true — показывает иконку отсутствия связи вместо общей ошибки.
  final bool isConnectionError;

  const AppErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
    this.isConnectionError = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return NebulaSurface(
      padding: const EdgeInsets.all(24),
      radiusRole: NebulaRadiusRole.panel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnectionError
                ? Icons.wifi_off_rounded
                : Icons.error_outline_rounded,
            color: tokens.mutedText,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            isConnectionError ? 'Нет соединения' : 'Ошибка загрузки',
            style: type.titleS.copyWith(color: tokens.error),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: type.bodyS.copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: 12),
          NebulaTextButton(
            label: 'Повторить',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

/// Compact inline error card, used within content areas (e.g. rates section).
class AppInlineErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppInlineErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return NebulaSurface(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: tokens.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: type.labelM.copyWith(color: tokens.secondaryText),
            ),
          ),
          NebulaTextButton(
            label: 'Повторить',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            compact: true,
          ),
        ],
      ),
    );
  }
}
