import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_background_host.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../providers/room_board_providers.dart';
import '../util/block_conflicts.dart';
import '../util/teacher_color.dart';
import '../widgets/assign_block_sheet.dart';
import '../widgets/block_actions_sheet.dart';
import '../widgets/room_edit_sheet.dart';

const _dayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _monthsShort = [
  'янв', 'фев', 'мар', 'апр', 'мая', 'июн', //
  'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
];

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

int _slotCount() =>
    ((BoardGrid.endMinutes - BoardGrid.startMinutes) / BoardGrid.slotMinutes)
        .floor();

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '—';
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((w) => w.characters.first).join().toUpperCase();
}

/// One room's weekly schedule as a grid — rows are 45-min time slots
/// (09:00–21:00), columns are Пн–Вс, each cell is a teacher assignment. Admins
/// tap an empty cell to assign and a filled cell to cancel/delete; teachers
/// read it.
class RoomScheduleScreen extends ConsumerWidget {
  final Room room;
  const RoomScheduleScreen({super.key, required this.room});

  /// Opens the schedule with a light fade (no heavy transition).
  static void show(BuildContext context, Room room) {
    Navigator.of(context, rootNavigator: true).push(
      FadePageRoute(builder: (_) => RoomScheduleScreen(room: room)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);

    final weekStart = _mondayOf(ref.watch(boardDateProvider));
    final days = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    final queries = [for (final d in days) (date: _ymd(d), teacherId: null)];
    final asyncs = [
      for (final q in queries) ref.watch(roomBlocksForDateProvider(q))
    ];

    void shiftWeek(int delta) {
      ref.read(boardDateProvider.notifier).state =
          weekStart.add(Duration(days: delta * 7));
    }

    void refresh() {
      for (final q in queries) {
        ref.invalidate(roomBlocksForDateProvider(q));
      }
    }

    Future<void> onEmptyTap(int weekday, int startMin) async {
      if (!isAdmin) return;
      final created = await AssignBlockSheet.show(
        context,
        weekStart: weekStart,
        fixedRoomId: room.id,
        fixedRoomName: room.name,
        fixedWeekdayIndex: weekday,
        fixedStartMin: startMin,
      );
      if (created) refresh();
    }

    Future<void> onBlockTap(ResolvedRoomBlock block, DateTime day) async {
      if (!isAdmin) return;
      final changed = await BlockActionsSheet.show(
        context,
        block: block,
        dateYmd: _ymd(day),
      );
      if (changed) refresh();
    }

    Future<void> renameRoom() async {
      final ok = await RoomEditSheet.show(context, existing: room);
      if (ok) {
        ref.invalidate(roomsProvider);
        if (context.mounted) Navigator.of(context).pop();
      }
    }

    Future<void> archiveRoom() async {
      final confirm = await NebulaDialog.confirm(
        context,
        title: 'Архивировать кабинет?',
        message:
            '«${room.name}» скроется. Назначения сохранятся, кабинет можно вернуть.',
        confirmLabel: 'Архивировать',
      );
      if (!confirm) return;
      try {
        await ref.read(roomsRepositoryProvider).updateRoom(room.id, isActive: false);
        ref.invalidate(roomsProvider);
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        if (context.mounted) {
          showNebulaSnackBar(context,
              title: 'Не удалось архивировать',
              message: parseApiError(e, fallback: 'Попробуйте снова'),
              tone: NebulaSnackTone.error);
        }
      }
    }

    Widget body;
    if (asyncs.any((a) => a.isLoading)) {
      body = const Center(child: OrbitLoader());
    } else if (asyncs.any((a) => a.hasError)) {
      final errored = asyncs.firstWhere((a) => a.hasError);
      body = Center(
        child: AppErrorCard(
          message: parseApiError(errored.error!,
              fallback: 'Не удалось загрузить расписание'),
          onRetry: refresh,
          isConnectionError: isConnectionError(errored.error!),
        ),
      );
    } else {
      // Blocks for this room, per weekday.
      final perDay = [
        for (var wd = 0; wd < 7; wd++)
          asyncs[wd].requireValue.where((b) => b.roomId == room.id).toList()
      ];
      final conflictIds = <int>{};
      for (final dayBlocks in perDay) {
        conflictIds.addAll(conflictingBlockIds(dayBlocks));
      }
      body = _ScheduleGrid(
        days: days,
        perDay: perDay,
        conflictIds: conflictIds,
        onEmptyTap: isAdmin ? onEmptyTap : null,
        onBlockTap: isAdmin ? onBlockTap : null,
      );
    }

    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeLabel = weekStart.month == weekEnd.month
        ? '${weekStart.day}–${weekEnd.day} ${_monthsShort[weekStart.month - 1]}'
        : '${weekStart.day} ${_monthsShort[weekStart.month - 1]} – '
            '${weekEnd.day} ${_monthsShort[weekEnd.month - 1]}';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundHost(
        darkBackground: AppDarkBackground.asciiWater,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 8, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Назад',
                      icon: Icon(Icons.arrow_back_rounded,
                          color: tokens.mutedText),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.titleM
                                  .copyWith(color: tokens.primaryText)),
                          Text('Расписание',
                              style: type.bodyS
                                  .copyWith(color: tokens.mutedText)),
                        ],
                      ),
                    ),
                    if (isAdmin) ...[
                      IconButton(
                        tooltip: 'Переименовать',
                        icon: Icon(Icons.edit_outlined,
                            color: tokens.mutedText),
                        onPressed: renameRoom,
                      ),
                      IconButton(
                        tooltip: 'Архивировать',
                        icon: Icon(Icons.archive_outlined,
                            color: tokens.mutedText),
                        onPressed: archiveRoom,
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Прошлая неделя',
                      icon: Icon(Icons.chevron_left_rounded,
                          color: tokens.primaryText),
                      onPressed: () => shiftWeek(-1),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(rangeLabel,
                            style: type.bodyM
                                .copyWith(color: tokens.secondaryText)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Следующая неделя',
                      icon: Icon(Icons.chevron_right_rounded,
                          color: tokens.primaryText),
                      onPressed: () => shiftWeek(1),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: body,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleGrid extends StatelessWidget {
  final List<DateTime> days;
  final List<List<ResolvedRoomBlock>> perDay;
  final Set<int> conflictIds;
  final void Function(int weekday, int startMin)? onEmptyTap;
  final void Function(ResolvedRoomBlock block, DateTime day)? onBlockTap;

  const _ScheduleGrid({
    required this.days,
    required this.perDay,
    required this.conflictIds,
    this.onEmptyTap,
    this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    const timeColW = 44.0;
    const cellH = 40.0;
    final slots = _slotCount();

    // For each weekday, map slot index -> covering block (and mark start slot).
    final coverBySlot = [for (var wd = 0; wd < 7; wd++) <int, ResolvedRoomBlock>{}];
    final startSlots = [for (var wd = 0; wd < 7; wd++) <int>{}];
    for (var wd = 0; wd < 7; wd++) {
      for (final b in perDay[wd]) {
        final s = ((hhmmToMinutes(b.startTime) - BoardGrid.startMinutes) /
                BoardGrid.slotMinutes)
            .floor();
        final e = ((hhmmToMinutes(b.endTime) - BoardGrid.startMinutes) /
                BoardGrid.slotMinutes)
            .ceil();
        for (var i = s; i < e; i++) {
          if (i < 0 || i >= slots) continue;
          coverBySlot[wd][i] = b;
        }
        if (s >= 0 && s < slots) startSlots[wd].add(s);
      }
    }

    return NebulaSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Day header row.
          SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: timeColW),
                for (var wd = 0; wd < 7; wd++)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_dayLabels[wd],
                              style: type.labelS.copyWith(
                                color: wd >= 5
                                    ? tokens.secondaryAccent
                                    : tokens.mutedText,
                                fontWeight: FontWeight.w700,
                              )),
                          Text('${days[wd].day}',
                              style: type.labelS
                                  .copyWith(color: tokens.mutedText)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.surfaceBorder),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: slots,
              itemBuilder: (context, ti) {
                final slotMin =
                    BoardGrid.startMinutes + ti * BoardGrid.slotMinutes;
                final timeStr =
                    '${(slotMin ~/ 60).toString().padLeft(2, '0')}:'
                    '${(slotMin % 60).toString().padLeft(2, '0')}';
                return SizedBox(
                  height: cellH,
                  child: Row(
                    children: [
                      SizedBox(
                        width: timeColW,
                        child: Center(
                          child: Text(timeStr,
                              style: type.overline
                                  .copyWith(color: tokens.mutedText)),
                        ),
                      ),
                      for (var wd = 0; wd < 7; wd++)
                        Expanded(
                          child: _Cell(
                            block: coverBySlot[wd][ti],
                            isStart: startSlots[wd].contains(ti),
                            isConflict: coverBySlot[wd][ti] != null &&
                                conflictIds.contains(coverBySlot[wd][ti]!.id),
                            onTap: () {
                              final block = coverBySlot[wd][ti];
                              if (block != null) {
                                onBlockTap?.call(block, days[wd]);
                              } else {
                                onEmptyTap?.call(wd, slotMin);
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final ResolvedRoomBlock? block;
  final bool isStart;
  final bool isConflict;
  final VoidCallback onTap;

  const _Cell({
    required this.block,
    required this.isStart,
    required this.isConflict,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final b = block;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: b == null
              ? Colors.transparent
              : teacherColor(b.teacherUserId)
                  .withValues(alpha: NebulaAlpha.surface),
          borderRadius: NebulaRadii.compactControlBorder,
          border: b == null
              ? Border.all(
                  color: tokens.surfaceBorder.withValues(alpha: NebulaAlpha.mist))
              : Border.all(
                  color: isConflict
                      ? NebulaColors.errorRose
                      : teacherColor(b.teacherUserId)
                          .withValues(alpha: NebulaAlpha.border)),
        ),
        alignment: Alignment.center,
        child: (b != null && isStart)
            ? Text(
                _initials(b.teacherName),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: type.labelS.copyWith(color: tokens.primaryText),
              )
            : null,
      ),
    );
  }
}
