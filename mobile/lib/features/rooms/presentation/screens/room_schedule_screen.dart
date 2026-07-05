import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_tokens.dart';
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
import '../../../../shared/widgets/stellar_button.dart';
import '../../../admin/data/admin_repository.dart';
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

// Grid geometry (single source for layout AND gesture math).
const double _timeColW = 44;
const double _cellH = 40;
const double _cellGap = 1.5;

DateTime _mondayOf(DateTime d) =>
    DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

String _fmtMin(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:'
    '${(m % 60).toString().padLeft(2, '0')}';

int _slotCount() =>
    ((BoardGrid.endMinutes - BoardGrid.startMinutes) / BoardGrid.slotMinutes)
        .floor();

String _initials(String? name) {
  if (name == null || name.trim().isEmpty) return '—';
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.take(2).map((w) => w.characters.first).join().toUpperCase();
}

/// One painted-in-edit-mode assignment: a contiguous run of slots for one
/// teacher on one weekday, ready to become a room block.
@visibleForTesting
class PaintedRange {
  final int weekday;
  final int teacherId;
  final int startMin;
  final int endMin;

  const PaintedRange({
    required this.weekday,
    required this.teacherId,
    required this.startMin,
    required this.endMin,
  });
}

/// Groups painted slots into per-day contiguous ranges (split when the run
/// breaks or the teacher changes), converting slot indices to minutes.
@visibleForTesting
List<PaintedRange> mergePaintedSlots(Map<({int wd, int slot}), int> pending) {
  PaintedRange range(int wd, int teacher, int startSlot, int endSlot) =>
      PaintedRange(
        weekday: wd,
        teacherId: teacher,
        startMin: BoardGrid.startMinutes + startSlot * BoardGrid.slotMinutes,
        endMin: BoardGrid.startMinutes + (endSlot + 1) * BoardGrid.slotMinutes,
      );

  final ranges = <PaintedRange>[];
  for (var wd = 0; wd < 7; wd++) {
    final entries = pending.entries.where((e) => e.key.wd == wd).toList()
      ..sort((a, b) => a.key.slot.compareTo(b.key.slot));
    int? runStart;
    int? prevSlot;
    int? teacher;
    for (final e in entries) {
      final s = e.key.slot;
      if (runStart != null && (s != prevSlot! + 1 || e.value != teacher)) {
        ranges.add(range(wd, teacher!, runStart, prevSlot));
        runStart = null;
      }
      runStart ??= s;
      teacher = e.value;
      prevSlot = s;
    }
    if (runStart != null) ranges.add(range(wd, teacher!, runStart, prevSlot!));
  }
  return ranges;
}

/// One room's weekly schedule as a grid — rows are 45-min time slots
/// (09:00–21:00), columns are Пн–Вс. Blocks render as single merged tiles
/// spanning their slots. Admins get a paint mode: pick a teacher brush and
/// fill slots by tap / long-press-drag, then save the batch.
class RoomScheduleScreen extends ConsumerStatefulWidget {
  final Room room;
  const RoomScheduleScreen({super.key, required this.room});

  /// Opens the schedule with a light fade (no heavy transition).
  static void show(BuildContext context, Room room) {
    Navigator.of(context, rootNavigator: true).push(
      FadePageRoute(builder: (_) => RoomScheduleScreen(room: room)),
    );
  }

  @override
  ConsumerState<RoomScheduleScreen> createState() => _RoomScheduleScreenState();
}

class _RoomScheduleScreenState extends ConsumerState<RoomScheduleScreen> {
  bool _editMode = false;
  int? _brushTeacherId;
  bool _recurring = true;
  bool _saving = false;
  final Map<({int wd, int slot}), int> _pending = {};
  final ScrollController _gridScroll = ScrollController();

  Room get room => widget.room;

  @override
  void dispose() {
    _gridScroll.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    HapticFeedback.lightImpact();
    setState(() {
      _editMode = !_editMode;
      if (!_editMode) {
        _pending.clear();
        _brushTeacherId = null;
      }
    });
  }

  /// Режим текущего pan-жеста: null вне жеста; true — жест-ластик.
  /// Определяется ПЕРВОЙ ячейкой свайпа (стартовал на закрашенной —
  /// стираем всю линию), чтобы проход туда-обратно не «мигал».
  bool? _panErasing;
  final Set<({int wd, int slot})> _panVisited = {};

  void _paintSlot(int wd, int slot) {
    final brush = _brushTeacherId;
    if (brush == null) return;
    final pos = (wd: wd, slot: slot);
    if (_pending[pos] == brush) return;
    HapticFeedback.selectionClick();
    setState(() => _pending[pos] = brush);
  }

  void _eraseSlot(int wd, int slot) {
    final removed = _pending.remove((wd: wd, slot: slot));
    if (removed != null) {
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  void _handleCellPan(int wd, int slot, {required bool start}) {
    if (_brushTeacherId == null) return;
    final pos = (wd: wd, slot: slot);
    if (start) {
      _panErasing = _pending.containsKey(pos);
      _panVisited.clear();
    }
    // Каждую ячейку жест трогает один раз — без мигания при проходе назад.
    if (!_panVisited.add(pos)) return;
    if (_panErasing ?? false) {
      _eraseSlot(wd, slot);
    } else {
      _paintSlot(wd, slot);
    }
  }

  void _handleCellPanEnd() {
    _panErasing = null;
    _panVisited.clear();
  }

  void _handleCellTap(int wd, int slot) {
    if (_brushTeacherId == null) return;
    if (_pending.containsKey((wd: wd, slot: slot))) {
      _eraseSlot(wd, slot);
    } else {
      _paintSlot(wd, slot);
    }
  }

  Future<void> _savePending(DateTime weekStart, VoidCallback refresh) async {
    if (_pending.isEmpty || _saving) return;
    setState(() => _saving = true);
    final ranges = mergePaintedSlots(_pending);
    final repo = ref.read(roomsRepositoryProvider);
    try {
      for (final r in ranges) {
        await repo.createBlock(
          roomId: room.id,
          teacherUserId: r.teacherId,
          startTime: _fmtMin(r.startMin),
          endTime: _fmtMin(r.endMin),
          weekday: _recurring ? r.weekday : null,
          specificDate: _recurring
              ? null
              : _ymd(weekStart.add(Duration(days: r.weekday))),
        );
      }
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      setState(() {
        _pending.clear();
        _editMode = false;
        _brushTeacherId = null;
        _saving = false;
      });
      refresh();
      showNebulaSnackBar(
        context,
        title: 'Расписание сохранено',
        message: ranges.length == 1
            ? 'Добавлен 1 блок'
            : 'Добавлено блоков: ${ranges.length}',
        tone: NebulaSnackTone.success,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showNebulaSnackBar(
        context,
        title: 'Не удалось сохранить',
        message: parseApiError(e, fallback: 'Попробуйте снова'),
        tone: NebulaSnackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        await ref
            .read(roomsRepositoryProvider)
            .updateRoom(room.id, isActive: false);
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
        editMode: _editMode,
        brushTeacherId: _brushTeacherId,
        pending: _pending,
        scrollController: _gridScroll,
        onCellPan: _handleCellPan,
        onCellPanEnd: _handleCellPanEnd,
        onCellTap: _handleCellTap,
        onEmptyTap: isAdmin && !_editMode ? onEmptyTap : null,
        onBlockTap: isAdmin && !_editMode ? onBlockTap : null,
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
                          Text(_editMode ? 'Редактирование' : 'Расписание',
                              style:
                                  type.bodyS.copyWith(color: tokens.mutedText)),
                        ],
                      ),
                    ),
                    if (isAdmin) ...[
                      IconButton(
                        key: const ValueKey('room-edit-toggle'),
                        tooltip: _editMode
                            ? 'Выйти из редактирования'
                            : 'Заполнить расписание',
                        icon: Icon(
                          _editMode
                              ? Icons.brush_rounded
                              : Icons.brush_outlined,
                          color:
                              _editMode ? tokens.focusAccent : tokens.mutedText,
                        ),
                        onPressed: _saving ? null : _toggleEdit,
                      ),
                      if (!_editMode) ...[
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
                  ],
                ),
              ),
              if (_editMode)
                _BrushStrip(
                  selectedTeacherId: _brushTeacherId,
                  onSelect: (id) {
                    HapticFeedback.selectionClick();
                    setState(() => _brushTeacherId = id);
                  },
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Прошлая неделя',
                      icon: Icon(Icons.chevron_left_rounded,
                          color: _editMode
                              ? tokens.mutedText
                              : tokens.primaryText),
                      onPressed: _editMode ? null : () => shiftWeek(-1),
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
                          color: _editMode
                              ? tokens.mutedText
                              : tokens.primaryText),
                      onPressed: _editMode ? null : () => shiftWeek(1),
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
              if (_editMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: StellarButton(
                          key: const ValueKey('paint-save'),
                          label: _pending.isEmpty
                              ? 'Сохранить'
                              : 'Сохранить (${_pending.length})',
                          icon: Icons.check_rounded,
                          loading: _saving,
                          onPressed: _pending.isEmpty || _saving
                              ? null
                              : () => _savePending(weekStart, refresh),
                        ),
                      ),
                      const SizedBox(width: NebulaTokens.sp8),
                      _RecurringToggle(
                        recurring: _recurring,
                        onChanged: (v) {
                          HapticFeedback.selectionClick();
                          setState(() => _recurring = v);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Edit chrome: teacher brush strip + recurrence
// ─────────────────────────────────────────────

class _BrushStrip extends ConsumerWidget {
  final int? selectedTeacherId;
  final ValueChanged<int> onSelect;

  const _BrushStrip({
    required this.selectedTeacherId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final usersAsync = ref.watch(orgUsersProvider);

    return SizedBox(
      height: 44,
      child: usersAsync.when(
        loading: () => const Center(child: OrbitLoader(size: 18)),
        error: (_, __) => Center(
          child: AppInlineErrorCard(
            message: 'Не удалось загрузить педагогов',
            onRetry: () => ref.invalidate(orgUsersProvider),
          ),
        ),
        data: (users) {
          final teachers =
              users.where((u) => u.role.toUpperCase() == 'TEACHER').toList();
          if (teachers.isEmpty) {
            return Center(
              child: Text('Нет педагогов',
                  style: type.bodyS.copyWith(color: tokens.mutedText)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: teachers.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: NebulaTokens.sp8),
            itemBuilder: (context, i) {
              final t = teachers[i];
              final color = teacherColor(t.id);
              final selected = t.id == selectedTeacherId;
              return GestureDetector(
                key: ValueKey('brush-teacher-${t.id}'),
                onTap: () => onSelect(t.id),
                child: AnimatedContainer(
                  duration: NebulaTokens.feedback,
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: NebulaTokens.sp12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(
                        alpha:
                            selected ? NebulaAlpha.subtle : NebulaAlpha.mist),
                    borderRadius: NebulaRadii.pillBorder,
                    border: Border.all(
                      color: color.withValues(
                          alpha: selected
                              ? NebulaAlpha.strong
                              : NebulaAlpha.border),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color:
                                  color.withValues(alpha: NebulaAlpha.subtle),
                              blurRadius: 12,
                              offset: Offset.zero,
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: NebulaTokens.sp8),
                      Text(
                        t.displayName,
                        style: type.labelM.copyWith(
                          color: selected
                              ? tokens.primaryText
                              : tokens.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RecurringToggle extends StatelessWidget {
  final bool recurring;
  final ValueChanged<bool> onChanged;

  const _RecurringToggle({required this.recurring, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return GestureDetector(
      key: const ValueKey('paint-recurring-toggle'),
      onTap: () => onChanged(!recurring),
      child: AnimatedContainer(
        duration: NebulaTokens.feedback,
        curve: Curves.easeOut,
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: NebulaTokens.sp12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: recurring
              ? tokens.focusAccent.withValues(alpha: NebulaAlpha.surface)
              : tokens.surface,
          borderRadius: NebulaRadii.controlBorder,
          border: Border.all(
            color: recurring
                ? tokens.focusAccent.withValues(alpha: NebulaAlpha.medium)
                : tokens.surfaceBorder,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              recurring ? Icons.repeat_rounded : Icons.looks_one_outlined,
              size: 18,
              color: recurring ? tokens.focusAccent : tokens.secondaryText,
            ),
            const SizedBox(height: NebulaTokens.sp2),
            Text(
              recurring ? 'Каждую нед.' : 'Эта неделя',
              style: type.labelS.copyWith(
                color: recurring ? tokens.focusAccent : tokens.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Grid: background rows + merged block tiles + paint layer
// ─────────────────────────────────────────────

class _ScheduleGrid extends StatelessWidget {
  final List<DateTime> days;
  final List<List<ResolvedRoomBlock>> perDay;
  final Set<int> conflictIds;
  final bool editMode;
  final int? brushTeacherId;
  final Map<({int wd, int slot}), int> pending;
  final ScrollController scrollController;
  final void Function(int wd, int slot, {required bool start}) onCellPan;
  final VoidCallback onCellPanEnd;
  final void Function(int wd, int slot) onCellTap;
  final void Function(int weekday, int startMin)? onEmptyTap;
  final void Function(ResolvedRoomBlock block, DateTime day)? onBlockTap;

  const _ScheduleGrid({
    required this.days,
    required this.perDay,
    required this.conflictIds,
    required this.editMode,
    required this.brushTeacherId,
    required this.pending,
    required this.scrollController,
    required this.onCellPan,
    required this.onCellPanEnd,
    required this.onCellTap,
    this.onEmptyTap,
    this.onBlockTap,
  });

  /// Slot coverage per weekday — which slot indices an existing block spans.
  List<Map<int, ResolvedRoomBlock>> _coverage(int slots) {
    final coverBySlot = [
      for (var wd = 0; wd < 7; wd++) <int, ResolvedRoomBlock>{}
    ];
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
      }
    }
    return coverBySlot;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final slots = _slotCount();
    final coverBySlot = _coverage(slots);
    final today = DateTime.now();

    return NebulaSurface(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Day header row.
          SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: _timeColW),
                for (var wd = 0; wd < 7; wd++)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_dayLabels[wd],
                              style: type.labelS.copyWith(
                                color: _isSameDay(days[wd], today)
                                    ? tokens.focusAccent
                                    : wd >= 5
                                        ? tokens.secondaryAccent
                                        : tokens.mutedText,
                                fontWeight: FontWeight.w700,
                              )),
                          Text('${days[wd].day}',
                              style: type.labelS.copyWith(
                                color: _isSameDay(days[wd], today)
                                    ? tokens.focusAccent
                                    : tokens.mutedText,
                              )),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: tokens.surfaceBorder),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final colW = (constraints.maxWidth - _timeColW) / 7;

              ({int wd, int slot})? slotAt(Offset local) {
                final dx = local.dx - _timeColW;
                if (dx < 0) return null;
                final wd = (dx / colW).floor();
                final slot = (local.dy / _cellH).floor();
                if (wd < 0 || wd > 6 || slot < 0 || slot >= slots) {
                  return null;
                }
                return (wd: wd, slot: slot);
              }

              void panAt(Offset local, {required bool start}) {
                final pos = slotAt(local);
                if (pos == null) return;
                if (coverBySlot[pos.wd][pos.slot] != null) return;
                onCellPan(pos.wd, pos.slot, start: start);
              }

              final canPaint = editMode && brushTeacherId != null;

              // Держит рисование одним свайпом: когда палец подходит к краю
              // вьюпорта, подкручиваем сетку, чтобы линия докрашивалась без
              // отрыва пальца (скролл-жест в режиме кисти отдан рисованию).
              void autoScroll(double contentDy) {
                if (!scrollController.hasClients) return;
                final offset = scrollController.offset;
                final viewportDy = contentDy - offset;
                const edge = 56.0;
                const step = 10.0;
                final max = scrollController.position.maxScrollExtent;
                if (viewportDy < edge && offset > 0) {
                  scrollController.jumpTo((offset - step).clamp(0.0, max));
                } else if (viewportDy > constraints.maxHeight - edge &&
                    offset < max) {
                  scrollController.jumpTo((offset + step).clamp(0.0, max));
                }
              }

              return SingleChildScrollView(
                controller: scrollController,
                // В режиме кисти вертикальный жест — это рисование, не скролл:
                // прокрутку делает autoScroll у краёв.
                physics: canPaint
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  // .down: рисование начинается со слота, которого палец
                  // КОСНУЛСЯ, а не с точки, где жест прошёл touch-slop —
                  // иначе первый слот свайпа оставался незакрашенным.
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: canPaint
                      ? (d) => panAt(d.localPosition, start: true)
                      : null,
                  onPanUpdate: canPaint
                      ? (d) {
                          panAt(d.localPosition, start: false);
                          autoScroll(d.localPosition.dy);
                        }
                      : null,
                  onPanEnd: canPaint ? (_) => onCellPanEnd() : null,
                  onPanCancel: canPaint ? onCellPanEnd : null,
                  child: SizedBox(
                    height: slots * _cellH,
                    width: constraints.maxWidth,
                    child: Stack(
                      children: [
                        // Base layer: time labels + tappable empty cells.
                        Column(
                          children: [
                            for (var ti = 0; ti < slots; ti++)
                              SizedBox(
                                height: _cellH,
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: _timeColW,
                                      child: Center(
                                        child: Text(
                                          _fmtMin(BoardGrid.startMinutes +
                                              ti * BoardGrid.slotMinutes),
                                          style: type.overline.copyWith(
                                              color: tokens.mutedText),
                                        ),
                                      ),
                                    ),
                                    for (var wd = 0; wd < 7; wd++)
                                      Expanded(
                                        child: _EmptyCell(
                                          key: coverBySlot[wd][ti] == null
                                              ? ValueKey('cell-$wd-$ti')
                                              : null,
                                          onTap: () {
                                            if (coverBySlot[wd][ti] != null) {
                                              return;
                                            }
                                            if (editMode) {
                                              onCellTap(wd, ti);
                                              return;
                                            }
                                            onEmptyTap?.call(
                                                wd,
                                                BoardGrid.startMinutes +
                                                    ti * BoardGrid.slotMinutes);
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        // Merged block tiles.
                        for (var wd = 0; wd < 7; wd++)
                          ..._blockTiles(
                            context,
                            wd: wd,
                            colW: colW,
                            slots: slots,
                            tokens: tokens,
                            type: type,
                          ),

                        // Pending paint tiles (edit mode).
                        for (final r in mergePaintedSlots(pending))
                          _pendingTile(r, colW, tokens, type),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  List<Widget> _blockTiles(
    BuildContext context, {
    required int wd,
    required double colW,
    required int slots,
    required CosmoThemeTokens tokens,
    required NebulaTypography type,
  }) {
    final tiles = <Widget>[];
    for (final b in perDay[wd]) {
      var s = ((hhmmToMinutes(b.startTime) - BoardGrid.startMinutes) /
              BoardGrid.slotMinutes)
          .floor();
      var e = ((hhmmToMinutes(b.endTime) - BoardGrid.startMinutes) /
              BoardGrid.slotMinutes)
          .ceil();
      s = s.clamp(0, slots);
      e = e.clamp(0, slots);
      if (e <= s) continue;
      final span = e - s;
      final color = teacherColor(b.teacherUserId);
      final isConflict = conflictIds.contains(b.id);
      tiles.add(Positioned(
        key: ValueKey('block-${b.id}-$wd-$s'),
        left: _timeColW + wd * colW + _cellGap,
        top: s * _cellH + _cellGap,
        width: colW - _cellGap * 2,
        height: span * _cellH - _cellGap * 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap:
              onBlockTap == null ? null : () => onBlockTap!.call(b, days[wd]),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: NebulaTokens.sp4, vertical: NebulaTokens.sp2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: NebulaAlpha.surface),
              borderRadius: NebulaRadii.compactControlBorder,
              border: Border.all(
                color: isConflict
                    ? NebulaColors.errorRose
                    : color.withValues(alpha: NebulaAlpha.border),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _initials(b.teacherName),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: type.labelS.copyWith(color: tokens.primaryText),
                ),
                if (span >= 2)
                  Text(
                    '${b.startTime}–${b.endTime}',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: type.overline.copyWith(color: tokens.secondaryText),
                  ),
              ],
            ),
          ),
        ),
      ));
    }
    return tiles;
  }

  Widget _pendingTile(
    PaintedRange r,
    double colW,
    CosmoThemeTokens tokens,
    NebulaTypography type,
  ) {
    final startSlot =
        (r.startMin - BoardGrid.startMinutes) ~/ BoardGrid.slotMinutes;
    final span = (r.endMin - r.startMin) ~/ BoardGrid.slotMinutes;
    final color = teacherColor(r.teacherId);
    return Positioned(
      key: ValueKey('pending-${r.weekday}-$startSlot'),
      left: _timeColW + r.weekday * colW + _cellGap,
      top: startSlot * _cellH + _cellGap,
      width: colW - _cellGap * 2,
      height: span * _cellH - _cellGap * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Tap erases the single tapped slot, not the whole run.
        onTapDown: (d) => onCellTap(
          r.weekday,
          startSlot + (d.localPosition.dy / _cellH).floor().clamp(0, span - 1),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: NebulaAlpha.subtle),
            borderRadius: NebulaRadii.compactControlBorder,
            border: Border.all(
              color: color.withValues(alpha: NebulaAlpha.strong),
            ),
          ),
          child: Center(
            child: Icon(Icons.add_rounded,
                size: 16,
                color: Colors.white.withValues(alpha: NebulaAlpha.high)),
          ),
        ),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _EmptyCell extends StatelessWidget {
  final VoidCallback onTap;

  const _EmptyCell({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(_cellGap),
        decoration: BoxDecoration(
          borderRadius: NebulaRadii.compactControlBorder,
          border: Border.all(
            color: tokens.surfaceBorder.withValues(alpha: NebulaAlpha.mist),
          ),
        ),
      ),
    );
  }
}
