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

/// Полноэкранный индикатор режима «смотрю как педагог».
///
/// Вместо плашки-прямоугольника: тонкая оранжевая светящаяся окантовка по
/// периметру всего экрана (не занимает места, не перекрывает контент) +
/// плавающая овальная стеклянная кнопка с именем педагога и выходом.
/// Добавляется ПОВЕРХ контента — последним ребёнком Stack в шелле.
class ViewAsOverlay extends ConsumerWidget {
  const ViewAsOverlay({super.key});

  void _exit(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    ref.read(viewAsTeacherProvider.notifier).state = null;
    // Сбрасываем кэши: пользователь сменился — данные стали другими.
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

    return Positioned.fill(
      child: Stack(
        children: [
          // ── Окантовка по периметру ────────────────────────────────────
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ViewAsFramePainter(color: tokens.warning),
              ),
            ),
          ),

          // ── Плавающая овальная кнопка выхода ─────────────────────────
          Positioned(
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
                  Icon(
                    Icons.visibility_outlined,
                    color: tokens.warning,
                    size: 15,
                  ),
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
                  Icon(
                    Icons.close_rounded,
                    color: tokens.warning,
                    size: 15,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Рамка-индикатор: скруглённый контур с мягким внутренним свечением.
/// Свет рассеивается внутрь, основная линия тонкая — режим считывается
/// мгновенно, но контент остаётся нетронутым.
class _ViewAsFramePainter extends CustomPainter {
  final Color color;

  const _ViewAsFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(5),
      const Radius.circular(NebulaRadii.hero),
    );

    // Мягкое рассеянное свечение внутрь — широкая размытая обводка.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
        ..color = color.withValues(alpha: NebulaAlpha.mist),
    );

    // Основная тонкая линия.
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: NebulaAlpha.high),
    );
  }

  @override
  bool shouldRepaint(_ViewAsFramePainter old) => old.color != color;
}
