import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_background_host.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../providers/room_board_providers.dart';
import '../util/block_conflicts.dart';
import '../widgets/assign_block_sheet.dart';
import '../widgets/block_actions_sheet.dart';
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

/// Day board screen — rooms as columns, time as rows, showing the whole
/// studio's schedule. Admins can tap an empty cell to assign a block or tap a
/// block to cancel/delete it; teachers see the same board read-only. Swipe the
/// header (or use the arrows) to move between days.
///
/// [standalone] is true when the board is pushed as its own route (admin opens
/// it from rooms management): it then hosts its own background and shows a back
/// button. When embedded in the calendar's "Кабинеты" scope it stays false.
class RoomBoardScreen extends ConsumerWidget {
  final bool standalone;
  const RoomBoardScreen({super.key, this.standalone = false});

  /// Pushes the board full-screen over the shell (its own background, no shell
  /// chrome overlap).
  static void show(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      SpacePageRoute(builder: (_) => const RoomBoardScreen(standalone: true)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);

    final date = ref.watch(boardDateProvider);
    final dateYmd = DateFormat('yyyy-MM-dd').format(date);
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.isAdmin ?? false;

    // The board always shows the whole studio (all rooms, all teachers).
    // Only admins get the tap-to-edit affordances; teachers read it.
    final roomsAsync = ref.watch(roomsProvider);
    final blocksQuery = (date: dateYmd, teacherId: null);
    final blocksAsync = ref.watch(roomBlocksForDateProvider(blocksQuery));

    void goToPreviousDay() {
      ref.read(boardDateProvider.notifier).state =
          date.subtract(const Duration(days: 1));
    }

    void goToNextDay() {
      ref.read(boardDateProvider.notifier).state =
          date.add(const Duration(days: 1));
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

      Future<void> onEmptyTap(int roomId, int startMinutes) async {
        if (!isAdmin) return;
        final room = rooms.firstWhere((r) => r.id == roomId);
        final created = await AssignBlockSheet.show(
          context,
          roomId: roomId,
          roomName: room.name,
          date: date,
          initialStartMinutes: startMinutes,
        );
        if (created) ref.invalidate(roomBlocksForDateProvider(blocksQuery));
      }

      Future<void> onBlockTap(ResolvedRoomBlock block) async {
        if (!isAdmin) return;
        final changed = await BlockActionsSheet.show(
          context,
          block: block,
          dateYmd: dateYmd,
        );
        if (changed) ref.invalidate(roomBlocksForDateProvider(blocksQuery));
      }

      body = RoomBoardGrid(
        rooms: rooms,
        blocks: blocks,
        conflictIds: conflictIds,
        onEmptyTap: onEmptyTap,
        onBlockTap: onBlockTap,
      );
    }

    // Day-swipe lives on the header only — wrapping the board would fight the
    // room columns' horizontal scroll in the gesture arena.
    void onHeaderDragEnd(DragEndDetails details) {
      final velocity = details.primaryVelocity ?? 0;
      if (velocity < 0) {
        goToNextDay();
      } else if (velocity > 0) {
        goToPreviousDay();
      }
    }

    final content = SafeArea(
      child: Column(
        children: [
          if (standalone)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
                child: IconButton(
                  tooltip: 'Назад',
                  icon: Icon(Icons.arrow_back_rounded,
                      color: tokens.mutedText),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragEnd: onHeaderDragEnd,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
            ),
            Expanded(child: body),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: standalone
          ? AppBackgroundHost(
              darkBackground: AppDarkBackground.asciiWater,
              child: content,
            )
          : content,
    );
  }
}
