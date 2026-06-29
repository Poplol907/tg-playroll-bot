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

/// Admin sheet to assign a room to a teacher for a time interval — either
/// recurring (this weekday, every week) or a one-off on [date].
///
/// Returns `true` from [show] when a block was created.
class AssignBlockSheet extends ConsumerStatefulWidget {
  final int roomId;
  final String roomName;
  final DateTime date;
  final int initialStartMinutes;

  const AssignBlockSheet({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.date,
    required this.initialStartMinutes,
  });

  static Future<bool> show(
    BuildContext context, {
    required int roomId,
    required String roomName,
    required DateTime date,
    required int initialStartMinutes,
  }) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => AssignBlockSheet(
        roomId: roomId,
        roomName: roomName,
        date: date,
        initialStartMinutes: initialStartMinutes,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AssignBlockSheet> createState() => _AssignBlockSheetState();
}

String _fmt(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:'
    '${(m % 60).toString().padLeft(2, '0')}';

List<int> _allSlots() => [
      for (var m = BoardGrid.startMinutes;
          m <= BoardGrid.endMinutes;
          m += BoardGrid.slotMinutes)
        m,
    ];

class _AssignBlockSheetState extends ConsumerState<AssignBlockSheet> {
  late int _startMin;
  late int _endMin;
  int? _teacherId;
  bool _recurring = true;
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final slots = _allSlots();
    _startMin = widget.initialStartMinutes;
    if (!slots.contains(_startMin)) _startMin = BoardGrid.startMinutes;
    if (_startMin >= BoardGrid.endMinutes) {
      _startMin = BoardGrid.endMinutes - BoardGrid.slotMinutes;
    }
    _endMin = _startMin + BoardGrid.slotMinutes;
    if (_endMin > BoardGrid.endMinutes) _endMin = BoardGrid.endMinutes;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      final ymd = DateFormat('yyyy-MM-dd').format(widget.date);
      final note = _noteCtrl.text.trim();
      await ref.read(roomsRepositoryProvider).createBlock(
            roomId: widget.roomId,
            teacherUserId: _teacherId!,
            startTime: _fmt(_startMin),
            endTime: _fmt(_endMin),
            weekday: _recurring ? BoardGrid.contractWeekday(widget.date) : null,
            specificDate: _recurring ? null : ymd,
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
    final usersAsync = ref.watch(orgUsersProvider);
    final slots = _allSlots();
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Назначить · ${widget.roomName}',
          style: type.titleL.copyWith(color: tokens.primaryText),
        ),
        const SizedBox(height: 4),
        Text(dateStr, style: type.bodyS.copyWith(color: tokens.mutedText)),
        const SizedBox(height: 20),
        Text('ПЕДАГОГ', style: type.overline.copyWith(color: tokens.mutedText)),
        const SizedBox(height: 8),
        usersAsync.when(
          loading: () => const Center(child: OrbitLoader()),
          error: (_, __) => Text(
            'Не удалось загрузить педагогов',
            style: type.bodyM.copyWith(color: tokens.error),
          ),
          data: (users) {
            final teachers = users.where((u) => u.role == 'TEACHER').toList();
            if (teachers.isEmpty) {
              return Text(
                'Нет педагогов',
                style: type.bodyM.copyWith(color: tokens.mutedText),
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 44.0 * teachers.length.clamp(1, 5) + 8,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: teachers.length,
                itemBuilder: (_, i) {
                  final t = teachers[i];
                  final selected = _teacherId == t.id;
                  return GestureDetector(
                    onTap: () => setState(() => _teacherId = t.id),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? tokens.primaryAccent
                                .withValues(alpha: NebulaAlpha.subtle)
                            : tokens.surface,
                        borderRadius: NebulaRadii.controlBorder,
                        border: Border.all(
                          color: selected
                              ? tokens.primaryAccent
                                  .withValues(alpha: NebulaAlpha.strong)
                              : tokens.surfaceBorder,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.bodyM.copyWith(
                            color: selected
                                ? tokens.primaryText
                                : tokens.mutedText,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _timeDropdown(
                context,
                label: 'НАЧАЛО',
                value: _startMin,
                options: slots.where((m) => m < BoardGrid.endMinutes).toList(),
                onChanged: (v) => setState(() {
                  _startMin = v;
                  if (_endMin <= _startMin) {
                    _endMin =
                        (_startMin + BoardGrid.slotMinutes) > BoardGrid.endMinutes
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
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: type.bodyS.copyWith(color: tokens.error)),
        ],
        const SizedBox(height: 20),
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
                .map((m) =>
                    DropdownMenuItem(value: m, child: Text(_fmt(m))))
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
