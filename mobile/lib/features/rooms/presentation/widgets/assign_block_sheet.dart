import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../admin/data/admin_repository.dart';
import '../../data/rooms_repository.dart';
import '../providers/room_board_providers.dart';
import '../../../../shared/widgets/sheet_error_banner.dart';
import '../../../../shared/widgets/app_error_card.dart';

const _weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Admin sheet to assign a room to a teacher — pick room, weekday (within the
/// shown week), start/end and whether it repeats weekly or is a one-off.
/// Returns `true` from [show] when a block was created.
class AssignBlockSheet extends ConsumerStatefulWidget {
  final DateTime weekStart;

  /// When opened from a room grid cell, room / weekday / start are fixed and
  /// their pickers are hidden.
  final int? fixedRoomId;
  final String? fixedRoomName;
  final int? fixedWeekdayIndex;
  final int? fixedStartMin;

  const AssignBlockSheet({
    super.key,
    required this.weekStart,
    this.fixedRoomId,
    this.fixedRoomName,
    this.fixedWeekdayIndex,
    this.fixedStartMin,
  });

  static Future<bool> show(
    BuildContext context, {
    required DateTime weekStart,
    int? fixedRoomId,
    String? fixedRoomName,
    int? fixedWeekdayIndex,
    int? fixedStartMin,
  }) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => AssignBlockSheet(
        weekStart: weekStart,
        fixedRoomId: fixedRoomId,
        fixedRoomName: fixedRoomName,
        fixedWeekdayIndex: fixedWeekdayIndex,
        fixedStartMin: fixedStartMin,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AssignBlockSheet> createState() => _AssignBlockSheetState();
}

String _fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:'
    '${(m % 60).toString().padLeft(2, '0')}';

List<int> _allSlots() => [
      for (var m = BoardGrid.startMinutes;
          m <= BoardGrid.endMinutes;
          m += BoardGrid.slotMinutes)
        m,
    ];

class _AssignBlockSheetState extends ConsumerState<AssignBlockSheet> {
  int? _roomId;
  int _weekdayIndex = 0;
  int? _teacherId;
  int _startMin = BoardGrid.startMinutes;
  int _endMin = BoardGrid.startMinutes + BoardGrid.slotMinutes;
  bool _recurring = true;
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _roomId = widget.fixedRoomId;
    if (widget.fixedWeekdayIndex != null) {
      _weekdayIndex = widget.fixedWeekdayIndex!;
    } else {
      // Default the day to today when the current week is shown, else Monday.
      final now = DateTime.now();
      final diff = DateTime(now.year, now.month, now.day)
          .difference(widget.weekStart)
          .inDays;
      if (diff >= 0 && diff <= 6) _weekdayIndex = diff;
    }
    if (widget.fixedStartMin != null) {
      _startMin = widget.fixedStartMin!.clamp(
          BoardGrid.startMinutes, BoardGrid.endMinutes - BoardGrid.slotMinutes);
      _endMin = (_startMin + BoardGrid.slotMinutes)
          .clamp(BoardGrid.startMinutes, BoardGrid.endMinutes);
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_roomId == null) {
      setState(() => _error = 'Выберите кабинет');
      return;
    }
    if (_teacherId == null) {
      setState(() => _error = 'Выберите педагога');
      return;
    }
    if (_endMin <= _startMin) {
      setState(() => _error = 'Конец должен быть позже начала');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final date = widget.weekStart.add(Duration(days: _weekdayIndex));
      final note = _noteCtrl.text.trim();
      await ref.read(roomsRepositoryProvider).createBlock(
            roomId: _roomId!,
            teacherUserId: _teacherId!,
            startTime: _fmt(_startMin),
            endTime: _fmt(_endMin),
            weekday: _recurring ? _weekdayIndex : null,
            specificDate:
                _recurring ? null : DateFormat('yyyy-MM-dd').format(date),
            note: note.isEmpty ? null : note,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = parseApiError(e, fallback: 'Не удалось назначить кабинет');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final roomsAsync = ref.watch(roomsProvider);
    final usersAsync = ref.watch(orgUsersProvider);
    final slots = _allSlots();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Назначить кабинет',
            style: type.titleL.copyWith(color: tokens.primaryText)),
        if (widget.fixedRoomName != null ||
            widget.fixedWeekdayIndex != null) ...[
          const SizedBox(height: 4),
          Text(
            [
              if (widget.fixedRoomName != null) widget.fixedRoomName!,
              if (widget.fixedWeekdayIndex != null)
                _weekdayShort[widget.fixedWeekdayIndex!],
              // Время уже выбрано ячейкой — показываем его в шапке,
              // пикеры времени внизу скрыты.
              if (widget.fixedStartMin != null)
                '${_fmt(_startMin)}–${_fmt(_endMin)}',
            ].join('  ·  '),
            style: type.bodyS.copyWith(color: tokens.mutedText),
          ),
        ],
        const SizedBox(height: 20),

        // ── Room picker (hidden when the room is fixed by the cell) ──
        if (widget.fixedRoomId == null) ...[
          Text('КАБИНЕТ',
              style: type.overline.copyWith(color: tokens.mutedText)),
          const SizedBox(height: 8),
          roomsAsync.when(
            loading: () => const Center(child: OrbitLoader()),
            error: (_, __) => AppInlineErrorCard(
              message: 'Не удалось загрузить кабинеты',
              onRetry: () => ref.invalidate(roomsProvider),
            ),
            data: (rooms) {
              final active = rooms.where((r) => r.isActive).toList();
              if (active.isEmpty) {
                return Text('Сначала создайте кабинет',
                    style: type.bodyM.copyWith(color: tokens.mutedText));
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in active)
                    _Chip(
                      label: r.name,
                      selected: _roomId == r.id,
                      onTap: () => setState(() => _roomId = r.id),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],

        // ── Weekday picker (hidden when the day is fixed by the cell) ──
        if (widget.fixedWeekdayIndex == null) ...[
          Text('ДЕНЬ', style: type.overline.copyWith(color: tokens.mutedText)),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == 6 ? 0 : 6),
                    child: _Chip(
                      label: _weekdayShort[i],
                      selected: _weekdayIndex == i,
                      onTap: () => setState(() => _weekdayIndex = i),
                      center: true,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Teacher picker ──
        Text('ПЕДАГОГ', style: type.overline.copyWith(color: tokens.mutedText)),
        const SizedBox(height: 8),
        usersAsync.when(
          loading: () => const Center(child: OrbitLoader()),
          error: (_, __) => AppInlineErrorCard(
            message: 'Не удалось загрузить педагогов',
            onRetry: () => ref.invalidate(orgUsersProvider),
          ),
          data: (users) {
            final teachers = users.where((u) => u.role == 'TEACHER').toList();
            if (teachers.isEmpty) {
              return Text('Нет педагогов',
                  style: type.bodyM.copyWith(color: tokens.mutedText));
            }
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in teachers)
                  _Chip(
                    label: t.displayName,
                    selected: _teacherId == t.id,
                    onTap: () => setState(() => _teacherId = t.id),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // ── Time (скрыто, когда слот зафиксирован ячейкой сетки — остаются
        // только педагог, повторяемость и заметка) ──
        if (widget.fixedStartMin == null) ...[
          Row(
            children: [
              Expanded(
                child: _timeDropdown(
                  context,
                  label: 'НАЧАЛО',
                  value: _startMin,
                  options:
                      slots.where((m) => m < BoardGrid.endMinutes).toList(),
                  onChanged: (v) => setState(() {
                    _startMin = v;
                    if (_endMin <= _startMin) {
                      _endMin = (_startMin + BoardGrid.slotMinutes) >
                              BoardGrid.endMinutes
                          ? BoardGrid.endMinutes
                          : _startMin + BoardGrid.slotMinutes;
                    }
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _timeDropdown(
                  context,
                  label: 'КОНЕЦ',
                  value: _endMin,
                  options: slots.where((m) => m > _startMin).toList(),
                  onChanged: (v) => setState(() => _endMin = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Recurrence ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: NebulaRadii.controlBorder,
            border: Border.all(color: tokens.surfaceBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _recurring ? 'Каждую неделю' : 'Только в этот день',
                  style: type.bodyM.copyWith(color: tokens.primaryText),
                ),
              ),
              Switch(
                value: _recurring,
                onChanged: (v) => setState(() => _recurring = v),
                activeThumbColor: tokens.primaryAccent,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        NebulaInput(
          controller: _noteCtrl,
          hintText: 'Заметка (необязательно)',
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),
        SheetErrorBanner(error: _error),
        StellarButton(
          label: 'Назначить',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.add_rounded,
          color: tokens.primaryAccent,
        ),
      ],
    );
  }

  Widget _timeDropdown(
    BuildContext context, {
    required String label,
    required int value,
    required List<int> options,
    required ValueChanged<int> onChanged,
  }) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final opts = options.contains(value) ? options : [value, ...options];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: type.overline.copyWith(color: tokens.mutedText)),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: NebulaRadii.controlBorder,
            border: Border.all(color: tokens.surfaceBorder),
          ),
          child: DropdownButton<int>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: tokens.denseSurface,
            icon: Icon(Icons.expand_more_rounded,
                color: tokens.mutedText, size: 20),
            style: type.bodyM.copyWith(color: tokens.primaryText),
            items: opts
                .map((m) => DropdownMenuItem(value: m, child: Text(_fmt(m))))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}

/// Selectable pill used by the room / weekday / teacher pickers.
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool center;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: center ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected
              ? tokens.primaryAccent.withValues(alpha: NebulaAlpha.subtle)
              : tokens.surface,
          borderRadius: NebulaRadii.controlBorder,
          border: Border.all(
            color: selected
                ? tokens.primaryAccent.withValues(alpha: NebulaAlpha.strong)
                : tokens.surfaceBorder,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: type.bodyM.copyWith(
            color: selected ? tokens.primaryText : tokens.mutedText,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
