import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/nebula_tokens.dart';
import '../../core/utils/error_parser.dart';
import 'app_error_card.dart';
import 'orbit_loader.dart';

/// Единый рендер [AsyncValue] во всём приложении.
///
/// loading → OrbitLoader, error → AppErrorCard (или AppInlineErrorCard в
/// [compact]-режиме), data → [builder]. До этого ошибки загрузки рисовались
/// ~11 разными самодельными способами — один виджет вместо всех них, чтобы
/// сбой сети выглядел одинаково на любом экране.
class AppAsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final String fallbackMessage;

  /// Компактный режим — для встраивания внутрь карточек и шитов:
  /// строка-ошибка и маленький лоадер вместо полноразмерной панели.
  final bool compact;
  final bool skipLoadingOnRefresh;

  const AppAsyncView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.fallbackMessage = 'Не удалось загрузить',
    this.compact = false,
    this.skipLoadingOnRefresh = true,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: skipLoadingOnRefresh,
      loading: () => compact
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: NebulaTokens.sp8),
              child: Center(child: OrbitLoader(size: 18)),
            )
          : const Center(child: OrbitLoader()),
      error: (e, _) {
        final message = parseApiError(e, fallback: fallbackMessage);
        if (compact) {
          return AppInlineErrorCard(message: message, onRetry: onRetry);
        }
        return Center(
          child: AppErrorCard(
            message: message,
            onRetry: onRetry,
            isConnectionError: isConnectionError(e),
          ),
        );
      },
      data: builder,
    );
  }
}
