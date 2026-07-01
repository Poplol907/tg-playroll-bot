import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/app_platform.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../data/admin_repository.dart';
import '../providers/view_as_teacher_provider.dart';

/// View-as indicator: a floating glass pill (teacher name + exit) shown while
/// an admin browses as a teacher. The ambient "you're in view-as" cue is the
/// orange glow on the month island (see the shell); no full-screen frame.
class ViewAsOverlay extends ConsumerWidget {
  const ViewAsOverlay({super.key});

  void _exit(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(viewAsTeacherProvider.notifier).state = null;
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
    final type = NebulaTypography.of(context);

    // Над плавающей овальной капсулой нижнего бара (мобайл);
    // на десктопе нижнего бара нет — прижимаем к нижнему краю.
    final bottomOffset = AppPlatform.isDesktop
        ? 24.0
        : MediaQuery.of(context).viewPadding.bottom + 96.0;

    return Positioned(
      right: 16,
      bottom: bottomOffset,
      child: NebulaSurface(
        radiusRole: NebulaRadiusRole.pill,
        accent: tokens.warning,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        onTap: () => _exit(context, ref),
        glow: [
          BoxShadow(
            color: tokens.warning.withValues(alpha: NebulaAlpha.subtle),
            blurRadius: 20,
            spreadRadius: -2,
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_outlined, color: tokens.warning, size: 15),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                viewAs.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelM.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tokens.warning,
                ),
              ),
            ),
            const SizedBox(width: 7),
            Icon(Icons.close_rounded, color: tokens.warning, size: 15),
          ],
        ),
      ),
    );
  }
}
