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
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../providers/room_board_providers.dart';
import '../util/block_conflicts.dart';
import '../util/teacher_color.dart';
import '../widgets/assign_block_sheet.dart';
import '../widgets/block_actions_sheet.dart';

const _weekdaysRu = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье',
];

const _monthsRuGen = [
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

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Weekly room schedule — a readable agenda: one section per weekday
/// (Пн–Вс), each listing the studio's room assignments as
/// «Кабинет · Педагог · HH:MM–HH:MM». Shows the whole studio; admins can add
/// a block (＋) or tap a row to cancel/delete it, teachers read it.
///
/// [standalone] is true when pushed as its own route (admin opens it from
/// rooms management): it hosts its own background and shows a back button.
class RoomBoardScreen extends ConsumerWidget {
  final bool standalone;
  const RoomBoardScreen({super.key, this.standalone = false});

  static void show(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      SlideUpPageRoute(builder: (_) => const RoomBoardScreen(standalone: true)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);

    final anchor = ref.watch(boardDateProvider);
    final weekStart = _mondayOf(anchor);
    final days = [for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i))];
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;

    // The board shows the whole studio (all rooms, all teachers).
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

    Future<void> onAdd() async {
      final created = await AssignBlockSheet.show(context, weekStart: weekStart);
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
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        itemCount: days.length,
        itemBuilder: (_, i) {
          final day = days[i];
          final blocks = [...asyncs[i].requireValue]..sort((a, b) =>
              hhmmToMinutes(a.startTime).compareTo(hhmmToMinutes(b.startTime)));
          return _DaySection(
            day: day,
            blocks: blocks,
            conflictIds: conflictingBlockIds(blocks),
            onBlockTap: isAdmin ? (b) => onBlockTap(b, day) : null,
          );
        },
      );
    }

    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeLabel = weekStart.month == weekEnd.month
        ? '${weekStart.day}–${weekEnd.day} ${_monthsRuGen[weekStart.month - 1]}'
        : '${weekStart.day} ${_monthsRuGen[weekStart.month - 1]} – '
            '${weekEnd.day} ${_monthsRuGen[weekEnd.month - 1]}';

    final content = SafeArea(
      top: standalone,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
            child: Row(
              children: [
                if (standalone)
                  IconButton(
                    tooltip: 'Назад',
                    icon: Icon(Icons.arrow_back_rounded,
                        color: tokens.mutedText),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                IconButton(
                  tooltip: 'Прошлая неделя',
                  icon: Icon(Icons.chevron_left_rounded,
                      color: tokens.primaryText),
                  onPressed: () => shiftWeek(-1),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('Расписание кабинетов',
                          style: type.titleM.copyWith(color: tokens.primaryText)),
                      Text(rangeLabel,
                          style: type.bodyS.copyWith(color: tokens.mutedText)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Следующая неделя',
                  icon: Icon(Icons.chevron_right_rounded,
                      color: tokens.primaryText),
                  onPressed: () => shiftWeek(1),
                ),
                if (isAdmin)
                  IconButton(
                    tooltip: 'Назначить кабинет',
                    icon: Icon(Icons.add_rounded, color: tokens.primaryAccent),
                    onPressed: onAdd,
                  ),
              ],
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

class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<ResolvedRoomBlock> blocks;
  final Set<int> conflictIds;
  final void Function(ResolvedRoomBlock block)? onBlockTap;

  const _DaySection({
    required this.day,
    required this.blocks,
    required this.conflictIds,
    this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final isToday = DateUtils.isSameDay(day, DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: NebulaRadii.cardBorder,
        border: Border.all(
          color: isToday
              ? tokens.primaryAccent.withValues(alpha: NebulaAlpha.border)
              : tokens.surfaceBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _weekdaysRu[day.weekday - 1],
                style: type.titleS.copyWith(
                  color: isToday ? tokens.primaryAccent : tokens.primaryText,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${day.day} ${_monthsRuGen[day.month - 1]}',
                style: type.bodyS.copyWith(color: tokens.mutedText),
              ),
              const Spacer(),
              if (blocks.isNotEmpty)
                Text('${blocks.length}',
                    style: type.labelM.copyWith(color: tokens.mutedText)),
            ],
          ),
          if (blocks.isEmpty) ...[
            const SizedBox(height: 8),
            Text('Нет назначений',
                style: type.bodyS.copyWith(color: tokens.mutedText)),
          ] else
            for (final entry in _groupByRoom(blocks).entries) ...[
              const SizedBox(height: 12),
              Text(entry.key,
                  style: type.labelM.copyWith(color: tokens.secondaryText)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final block in entry.value)
                    _BlockChip(
                      block: block,
                      isConflict: conflictIds.contains(block.id),
                      onTap: onBlockTap == null
                          ? null
                          : () => onBlockTap!(block),
                    ),
                ],
              ),
            ],
        ],
      ),
    );
  }

  /// Groups a day's blocks by room (rooms alphabetical, slots by start time).
  Map<String, List<ResolvedRoomBlock>> _groupByRoom(
      List<ResolvedRoomBlock> blocks) {
    final map = <String, List<ResolvedRoomBlock>>{};
    for (final b in blocks) {
      (map[b.roomName] ??= []).add(b);
    }
    final keys = map.keys.toList()..sort();
    return {
      for (final k in keys)
        k: (map[k]!
          ..sort((a, b) => hhmmToMinutes(a.startTime)
              .compareTo(hhmmToMinutes(b.startTime)))),
    };
  }
}

/// A single assignment on the schedule — a teacher-tinted time chip.
class _BlockChip extends StatelessWidget {
  final ResolvedRoomBlock block;
  final bool isConflict;
  final VoidCallback? onTap;

  const _BlockChip({
    required this.block,
    required this.isConflict,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final color = teacherColor(block.teacherUserId);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: NebulaAlpha.surface),
          borderRadius: NebulaRadii.controlBorder,
          border: Border.all(
            color: isConflict
                ? NebulaColors.errorRose
                : color.withValues(alpha: NebulaAlpha.border),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${block.startTime}–${block.endTime}',
              style: type.labelM.copyWith(color: tokens.primaryText).copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            const SizedBox(width: 6),
            Text(
              block.teacherName ?? '—',
              style: type.labelM.copyWith(color: tokens.secondaryText),
            ),
            if (!block.isRecurring) ...[
              const SizedBox(width: 6),
              Icon(Icons.event_rounded, size: 12, color: tokens.mutedText),
            ],
            if (isConflict) ...[
              const SizedBox(width: 6),
              const Icon(Icons.warning_amber_rounded,
                  size: 12, color: NebulaColors.errorRose),
            ],
          ],
        ),
      ),
    );
  }
}
