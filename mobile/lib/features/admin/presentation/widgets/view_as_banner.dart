import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../providers/view_as_teacher_provider.dart';

/// Узкая полоса сверху, видимая когда админ просматривает данные педагога.
/// Показывает имя педагога и даёт кнопку выйти из режима.
class ViewAsBanner extends ConsumerWidget {
  const ViewAsBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewAs = ref.watch(viewAsTeacherProvider);
    if (viewAs == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: NebulaColors.warningAmber.withValues(alpha: 0.12),
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
                    const TextSpan(
                      text: 'Просматриваешь как: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: NebulaColors.mistWhite,
                      ),
                    ),
                    TextSpan(
                      text: viewAs.displayName,
                      style: const TextStyle(
                        fontSize: 12,
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
                  color: NebulaColors.warningAmber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
                  border: Border.all(
                    color: NebulaColors.warningAmber.withValues(alpha: 0.4),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: NebulaColors.warningAmber,
                      size: 12,
                    ),
                    SizedBox(width: NebulaTokens.sp4),
                    Text(
                      'Выйти',
                      style: TextStyle(
                        fontSize: 11,
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
