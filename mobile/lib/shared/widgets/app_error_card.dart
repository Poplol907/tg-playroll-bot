import 'package:flutter/material.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';
import 'nebula_surface.dart';
import 'nebula_text_button.dart';

/// Full-width error state shown when a data provider fails to load.
/// Style matches the salary screen error card.
class AppErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppErrorCard({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return NebulaSurface(
      padding: const EdgeInsets.all(24),
      borderRadius: NebulaTokens.radiusLG,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            color: NebulaColors.ghostText,
            size: 48,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ошибка загрузки',
            style: TextStyle(
              color: NebulaColors.errorRose,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: NebulaColors.mistWhite,
              fontSize: 13,
            ),
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
    return NebulaSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: NebulaTokens.radiusMD,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: NebulaColors.warningAmber,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: NebulaColors.mistWhite,
                fontSize: 12,
              ),
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
