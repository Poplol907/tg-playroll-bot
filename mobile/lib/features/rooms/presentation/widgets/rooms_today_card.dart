import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/rooms_repository.dart';

/// Compact "Мои кабинеты сегодня" card for teachers — today's room blocks for
/// the signed-in teacher. Renders nothing for non-teachers, so it can be placed
/// unconditionally at the top of the calendar.
class RoomsTodayCard extends ConsumerWidget {
  const RoomsTodayCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.isTeacher) return const SizedBox.shrink();

    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final ymd = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final blocksAsync =
        ref.watch(roomBlocksForDateProvider((date: ymd, teacherId: user.id)));

    final inner = blocksAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: OrbitLoader(size: 18)),
      ),
      error: (_, __) => Text(
        'Не удалось загрузить',
        style: type.bodyS.copyWith(color: tokens.mutedText),
      ),
      data: (blocks) {
        if (blocks.isEmpty) {
          return Text(
            'Вам пока не назначили кабинеты',
            style: type.bodyS.copyWith(color: tokens.mutedText),
          );
        }
        final sorted = [...blocks]
          ..sort((a, b) => a.startTime.compareTo(b.startTime));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final b in sorted)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 16, color: tokens.secondaryText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        b.roomName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.bodyM.copyWith(color: tokens.primaryText),
                      ),
                    ),
                    Text(
                      '${b.startTime}–${b.endTime}',
                      style: type.bodyS.copyWith(color: tokens.secondaryText).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: NebulaRadii.cardBorder,
          border: Border.all(color: tokens.surfaceBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'МОИ КАБИНЕТЫ СЕГОДНЯ',
              style: type.overline.copyWith(color: tokens.mutedText),
            ),
            const SizedBox(height: 6),
            inner,
          ],
        ),
      ),
    );
  }
}
