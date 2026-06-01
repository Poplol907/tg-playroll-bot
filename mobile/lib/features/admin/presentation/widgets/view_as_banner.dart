import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../providers/view_as_teacher_provider.dart';

/// Узкая полоса сверху, видимая когда админ просматривает данные педагога.
/// Показывает имя педагога и даёт кнопку выйти из режима.
class ViewAsBanner extends ConsumerWidget {
  const ViewAsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAs = ref.watch(viewAsTeacherProvider);
    if (viewAs == null) return const SizedBox.shrink();

    final type = NebulaTypography.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: NebulaColors.warningAmber.withValues(alpha: NebulaAlpha.surface),
          border: const Border(
            bottom: BorderSide(
              color: NebulaColors.warningAmber,
              width: 0.6,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: NebulaTokens.sp16,
          vertical: NebulaTokens.sp8,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              color: NebulaColors.warningAmber,
              size: 16,
            ),
            const SizedBox(width: NebulaTokens.sp8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Просматриваешь как: ',
                      style: type.labelM.copyWith(color: NebulaColors.mistWhite),
                    ),
                    TextSpan(
                      text: viewAs.displayName,
                      style: type.labelM.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NebulaColors.softWhite,
                      ),
                    ),
                  ],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: NebulaTokens.sp8),
            InkWell(
              borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(viewAsTeacherProvider.notifier).state = null;
                // Возвращаемся в админ-панель
                context.go('/admin');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NebulaTokens.sp12,
                  vertical: NebulaTokens.sp4,
                ),
                decoration: BoxDecoration(
                  color: NebulaColors.warningAmber
                      .withValues(alpha: NebulaAlpha.subtle),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
                  border: Border.all(
                    color: NebulaColors.warningAmber
                        .withValues(alpha: NebulaAlpha.medium),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: NebulaColors.warningAmber,
                      size: 12,
                    ),
                    const SizedBox(width: NebulaTokens.sp4),
                    Text(
                      'Выйти',
                      style: type.labelS.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NebulaColors.warningAmber,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
