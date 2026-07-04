import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/app_platform.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../shared/providers/bottom_bar_visibility_provider.dart';
import '../../../../shared/widgets/app_chrome_metrics.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../data/admin_repository.dart';
import '../providers/view_as_teacher_provider.dart';

/// View-as exit: a small round amber logout button under the month island.
/// The ambient "you're in view-as" cue is the island's orange glow (see the
/// shell); the button only needs to say "выход".
class ViewAsOverlay extends ConsumerWidget {
  const ViewAsOverlay({super.key});

  void _exit(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(viewAsTeacherProvider.notifier).state = null;
    // Смена роли — граница нормализации хрома: если бар/остров остались
    // спрятанными протухшим состоянием (прерванный runWithBottomBarHidden,
    // недобитый модальный цикл), админ вернулся бы к шеллу без навигации.
    ref.read(bottomBarVisibleProvider.notifier).state = true;
    ref.read(topIslandVisibleProvider.notifier).state = true;
    // Кэши пользователя сбросятся сами по смене личности; уводим на /admin.
    ref.invalidate(studioStatsProvider);
    context.go('/admin');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAs = ref.watch(viewAsTeacherProvider);
    if (viewAs == null) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    // Just below the month island, top-right — reads together with the island's
    // orange view-as glow instead of floating over the bottom nav.
    final topOffset = AppPlatform.isDesktop
        ? 16.0
        : MediaQuery.of(context).viewPadding.top +
            AppChromeMetrics.mobileTopIslandExtent +
            6;

    return Positioned(
      right: 16,
      top: topOffset,
      child: NebulaSurface(
        key: const ValueKey('view-as-exit'),
        shape: BoxShape.circle,
        accent: tokens.warning,
        width: 40,
        height: 40,
        padding: EdgeInsets.zero,
        onTap: () => _exit(context, ref),
        glow: [
          BoxShadow(
            color: tokens.warning.withValues(alpha: NebulaAlpha.subtle),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
        child: Center(
          child: Icon(Icons.logout_rounded, color: tokens.warning, size: 18),
        ),
      ),
    );
  }
}
