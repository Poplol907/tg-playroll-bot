import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../providers/room_board_providers.dart';
import '../util/block_conflicts.dart';
import '../widgets/room_board_grid.dart';

const _weekdaysRu = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const _monthsRu = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// Read-only day board screen — rooms as columns, time as rows.
/// Admins will get tap-to-act affordances in a later task; for now taps are
/// wired but no-op for non-admins (and TODO for admins).
class RoomBoardScreen extends ConsumerWidget {
  const RoomBoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);

    final date = ref.watch(boardDateProvider);
    final dateYmd = DateFormat('yyyy-MM-dd').format(date);
    final user = ref.watch(currentUserProvider);
    final teacherId = (user?.isTeacher ?? false) ? user!.id : null;
    final isAdmin = user?.isAdmin ?? false;

    final roomsAsync = ref.watch(roomsProvider);
    final blocksQuery = (date: dateYmd, teacherId: teacherId);
    final blocksAsync = ref.watch(roomBlocksForDateProvider(blocksQuery));

    void goToPreviousDay() {
      ref.read(boardDateProvider.notifier).state =
          date.subtract(const Duration(days: 1));
    }

    void goToNextDay() {
      ref.read(boardDateProvider.notifier).state =
          date.add(const Duration(days: 1));
    }

    void handleEmptyTap(int roomId, int startMinutes) {
      if (!isAdmin) return;
      // TODO(task3): open assign/actions sheet
    }

    void handleBlockTap(ResolvedRoomBlock block) {
      if (!isAdmin) return;
      // TODO(task3): open assign/actions sheet
    }

    void retry() {
      ref.invalidate(roomsProvider);
      ref.invalidate(roomBlocksForDateProvider(blocksQuery));
    }

    final weekdayLabel = _weekdaysRu[BoardGrid.contractWeekday(date)];
    final dateLabel = '${date.day} ${_monthsRu[date.month - 1]}';

    Widget body;
    if (roomsAsync.isLoading || blocksAsync.isLoading) {
      body = const Center(child: OrbitLoader());
    } else if (roomsAsync.hasError) {
      body = Center(
        child: AppErrorCard(
          message: parseApiError(
            roomsAsync.error!,
            fallback: 'Не удалось загрузить расписание',
          ),
          onRetry: retry,
          isConnectionError: isConnectionError(roomsAsync.error!),
        ),
      );
    } else if (blocksAsync.hasError) {
      body = Center(
        child: AppErrorCard(
          message: parseApiError(
            blocksAsync.error!,
            fallback: 'Не удалось загрузить расписание',
          ),
          onRetry: retry,
          isConnectionError: isConnectionError(blocksAsync.error!),
        ),
      );
    } else {
      final rooms = roomsAsync.requireValue;
      final blocks = blocksAsync.requireValue;
      final conflictIds = conflictingBlockIds(blocks);
      body = GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity < 0) {
            goToNextDay();
          } else if (velocity > 0) {
            goToPreviousDay();
          }
        },
        child: RoomBoardGrid(
          rooms: rooms,
          blocks: blocks,
          conflictIds: conflictIds,
          onEmptyTap: handleEmptyTap,
          onBlockTap: handleBlockTap,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: tokens.primaryText,
                    onPressed: goToPreviousDay,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          weekdayLabel,
                          style: type.titleM.copyWith(
                            color: tokens.primaryText,
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: type.bodyS.copyWith(
                            color: tokens.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    color: tokens.primaryText,
                    onPressed: goToNextDay,
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
