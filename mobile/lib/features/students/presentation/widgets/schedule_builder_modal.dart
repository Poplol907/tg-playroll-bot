import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_surface_profile.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../shared/models/student.dart';
import '../../../../shared/providers/data_refresh_provider.dart';
import '../../../../shared/providers/month_provider.dart';
import '../../../../shared/widgets/adaptive_modal.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../calendar/data/calendar_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Time slots: 08:00 – 21:00 every 30 min
// ─────────────────────────────────────────────────────────────────────────────

/// Generates time slots in 45-minute steps starting from 08:15 up to 21:00 inclusive.
/// 08:15 → 09:00 → 09:45 → 10:30 → … → 20:15 → 21:00
List<String> _buildTimeSlots() {
  final slots = <String>[];
  int totalMinutes = 8 * 60 + 15; // 08:15
  const endMinutes = 21 * 60; // 21:00 inclusive
  while (totalMinutes <= endMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    slots
        .add('${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}');
    totalMinutes += 45;
  }
  return slots;
}

final _kTimeSlots = _buildTimeSlots();

const _kDayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

// ─────────────────────────────────────────────────────────────────────────────
//  Model: selected slot = {weekday (0-6), time "HH:MM"}
// ─────────────────────────────────────────────────────────────────────────────

class _SlotKey {
  final int weekday; // 0 = Mon … 6 = Sun
  final String time; // "HH:MM"

  const _SlotKey(this.weekday, this.time);

  @override
  bool operator ==(Object other) =>
      other is _SlotKey && other.weekday == weekday && other.time == time;

  @override
  int get hashCode => Object.hash(weekday, time);

  Map<String, dynamic> toJson() => {'weekday': weekday, 'time': time};
}

// ─────────────────────────────────────────────────────────────────────────────
//  Entry point
// ─────────────────────────────────────────────────────────────────────────────

class ScheduleBuilderModal extends ConsumerStatefulWidget {
  final StudentModel student;
  final int studentTeacherId;

  const ScheduleBuilderModal({
    super.key,
    required this.student,
    required this.studentTeacherId,
  });

  /// Opens as a full-screen-ish DraggableScrollableSheet.
  static Future<bool> show(
    BuildContext context, {
    required StudentModel student,
    required int studentTeacherId,
  }) {
    final modal = ScheduleBuilderModal(
      student: student,
      studentTeacherId: studentTeacherId,
    );
    final resultFuture = AppPlatform.isDesktop
        ? AdaptiveModal.show<bool>(
            context,
            desktopWidth: 760,
            builder: (_) => modal,
          )
        : showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            useSafeArea: true,
            builder: (_) => modal,
          );
    return resultFuture.then((result) => result ?? false);
  }

  @override
  ConsumerState<ScheduleBuilderModal> createState() =>
      _ScheduleBuilderModalState();
}

class _ScheduleBuilderModalState extends ConsumerState<ScheduleBuilderModal> {
  final Set<_SlotKey> _selected = {};
  bool _loading = false;
  String? _errorMsg;

  // ── Compute preview dates from selected slots + current month ──────────────
  List<DateTime> _previewDates(String monthYear) {
    if (_selected.isEmpty) return [];

    final parts = monthYear.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    // weekday → list of times
    final byWd = <int, List<String>>{};
    for (final s in _selected) {
      byWd.putIfAbsent(s.weekday, () => []).add(s.time);
    }

    final dates = <DateTime>[];
    for (int d = 1; d <= daysInMonth; d++) {
      final dt = DateTime(year, month, d);
      final wd = dt.weekday - 1; // DateTime.weekday: 1=Mon, so -1 → 0=Mon
      final times = byWd[wd] ?? [];
      for (final t in times) {
        dates.add(DateTime(year, month, d, int.parse(t.split(':')[0]),
            int.parse(t.split(':')[1])));
      }
    }
    dates.sort();
    return dates;
  }

  Future<void> _submit(String monthYear) async {
    if (_selected.isEmpty) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    HapticFeedback.mediumImpact();

    try {
      final repo = ref.read(calendarRepositoryProvider);
      final result = await repo.createBulkLessons(
        studentTeacherId: widget.studentTeacherId,
        monthYear: monthYear,
        slots: _selected.map((s) => s.toJson()).toList(),
      );

      final created = result['lessons_created'] as int;
      final warnings = (result['warnings'] as List?)?.cast<String>() ?? [];

      invalidateMonthData(ref, monthYear);

      if (mounted) {
        // Show warnings snackbar if any slots were skipped
        if (warnings.isNotEmpty) {
          showNebulaSnackBar(
            context,
            title: 'Пропущено ${warnings.length} слот(ов)',
            message: warnings.first,
            tone: NebulaSnackTone.warning,
            duration: const Duration(seconds: 5),
          );
        }
        Navigator.of(context).pop(true);
        HapticFeedback.heavyImpact();
        // Show success snackbar in parent context
        showNebulaSnackBar(
          context,
          title: 'Создано $created уроков',
          message: monthYear,
          tone: NebulaSnackTone.success,
        );
      }
    } catch (e) {
      setState(() {
        _errorMsg = parseApiError(e, fallback: 'Не удалось создать расписание');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final monthYear = ref.watch(globalMonthYearProvider);
    final monthDt = DateFormat('yyyy-MM').parse(monthYear);
    final monthLabel = DateFormat('MMMM yyyy', 'ru').format(monthDt);
    final preview = _previewDates(monthYear);

    if (AppPlatform.isDesktop) {
      return _buildDesktopPanel(
        context,
        monthYear: monthYear,
        monthLabel: monthLabel,
        preview: preview,
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.92, 1.0],
      expand: false,
      builder: (ctx, scrollCtrl) {
        return _buildMobileSheet(
          context,
          scrollCtrl: scrollCtrl,
          monthYear: monthYear,
          monthLabel: monthLabel,
          preview: preview,
        );
      },
    );
  }

  Widget _buildDesktopPanel(
    BuildContext context, {
    required String monthYear,
    required String monthLabel,
    required List<DateTime> preview,
  }) {
    final height = MediaQuery.of(context).size.height * 0.82;

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          children: [
            _Header(
              studentName: widget.student.fullName,
              monthLabel: monthLabel,
              showHandle: false,
            ),
            const Divider(height: 20, color: NebulaColors.surfaceBorder),
            const _GridLabel(),
            const SizedBox(height: 8),
            SizedBox(
              height: 348,
              child: _WeekGrid(
                selected: _selected,
                onToggle: _toggleSlot,
                compact: true,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: _ActionArea(
                  selected: _selected,
                  preview: preview,
                  monthLabel: monthLabel,
                  isForeign: widget.student.isForeign,
                  errorMsg: _errorMsg,
                  loading: _loading,
                  onSubmit: () => _submit(monthYear),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileSheet(
    BuildContext context, {
    required ScrollController scrollCtrl,
    required String monthYear,
    required String monthLabel,
    required List<DateTime> preview,
  }) {
    final surface = NebulaSurfaceProfile.modal.resolve(context);
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(NebulaTokens.radiusXL),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface.fill,
          gradient: surface.sheen,
          border: Border(
            top: BorderSide(
              color: surface.border,
              width: surface.borderWidth,
            ),
            left: BorderSide(
              color: surface.border,
              width: surface.borderWidth,
            ),
            right: BorderSide(
              color: surface.border,
              width: surface.borderWidth,
            ),
          ),
          boxShadow: surface.shadows,
        ),
        child: Column(
          children: [
            _Header(
              studentName: widget.student.fullName,
              monthLabel: monthLabel,
              showHandle: true,
            ),
            const Divider(height: 16, color: NebulaColors.surfaceBorder),
            // Label — static, never scrolls
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _GridLabel(),
            ),
            // Grid — fills remaining height; header row is pinned inside
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _WeekGrid(
                  selected: _selected,
                  onToggle: _toggleSlot,
                  scrollController: scrollCtrl,
                ),
              ),
            ),
            // Action area — always visible below the grid
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: _ActionArea(
                selected: _selected,
                preview: preview,
                monthLabel: monthLabel,
                isForeign: widget.student.isForeign,
                errorMsg: _errorMsg,
                loading: _loading,
                onSubmit: () => _submit(monthYear),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSlot(_SlotKey slot) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(slot)) {
        _selected.remove(slot);
      } else {
        _selected.add(slot);
      }
    });
  }
}

class _Header extends StatelessWidget {
  final String studentName;
  final String monthLabel;
  final bool showHandle;

  const _Header({
    required this.studentName,
    required this.monthLabel,
    required this.showHandle,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Column(
      children: [
        if (showHandle)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.mutedText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: showHandle ? 20 : 0,
            vertical: showHandle ? 4 : 0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Расписание',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: tokens.primaryText,
                      ),
                    ),
                    Text(
                      '$studentName · $monthLabel',
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(false),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: NebulaColors.nebulaSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: NebulaColors.surfaceBorder),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: tokens.mutedText,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GridLabel extends StatelessWidget {
  const _GridLabel();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'ВЫБЕРИТЕ ДЕНЬ И ВРЕМЯ',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: NebulaColors.ghostText,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  final Set<_SlotKey> selected;
  final List<DateTime> preview;
  final String monthLabel;
  final bool isForeign;
  final String? errorMsg;
  final bool loading;
  final VoidCallback onSubmit;

  const _ActionArea({
    required this.selected,
    required this.preview,
    required this.monthLabel,
    required this.isForeign,
    required this.errorMsg,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected.isNotEmpty) ...[
          _PreviewSection(
            preview: preview,
            monthLabel: monthLabel,
            isForeign: isForeign,
          ),
          const SizedBox(height: 16),
        ],
        if (errorMsg != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: NebulaColors.errorRose.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
              border: Border.all(
                color: NebulaColors.errorRose.withValues(alpha: 0.3),
              ),
            ),
            child: Row(children: [
              const Icon(
                Icons.error_outline_rounded,
                color: NebulaColors.errorRose,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMsg!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: NebulaColors.errorRose,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        _ConfirmButton(
          count: preview.length,
          loading: loading,
          enabled: selected.isNotEmpty && !loading,
          onTap: onSubmit,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Weekly grid
// ─────────────────────────────────────────────────────────────────────────────

class _WeekGrid extends StatelessWidget {
  final Set<_SlotKey> selected;
  final void Function(_SlotKey) onToggle;
  final bool compact;
  final ScrollController? scrollController;

  const _WeekGrid({
    required this.selected,
    required this.onToggle,
    this.compact = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final timeColW = compact ? 42.0 : 46.0;
    final cellH = compact ? 32.0 : 38.0;
    final headerH = compact ? 30.0 : 32.0;

    return NebulaSurface(
      padding: EdgeInsets.zero,
      borderRadius: NebulaTokens.radiusMD,
      child: Column(
        children: [
          // ── Day header row ────────────────────────────────────────────
          SizedBox(
            height: headerH,
            child: Row(
              children: [
                SizedBox(width: timeColW), // empty corner
                ...List.generate(7, (wd) {
                  final isWeekend = wd >= 5;
                  return Expanded(
                    child: Center(
                      child: Text(
                        _kDayLabels[wd],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isWeekend
                              ? NebulaColors.nebulaPurple
                              : NebulaColors.dimText,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const Divider(height: 1, color: NebulaColors.surfaceBorder),

          // ── Time rows ─────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              controller: scrollController,
              primary: scrollController == null,
              itemCount: _kTimeSlots.length,
              itemBuilder: (context, ti) {
                final timeStr = _kTimeSlots[ti];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (ti > 0)
                      const Divider(
                        height: 1,
                        color: NebulaColors.surfaceBorder,
                      ),
                    SizedBox(
                      height: cellH,
                      child: Row(
                        children: [
                          // Time label
                          SizedBox(
                            width: timeColW,
                            child: Center(
                              child: Text(
                                timeStr,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: NebulaColors.dimText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          // Day cells
                          ...List.generate(7, (wd) {
                            final slot = _SlotKey(wd, timeStr);
                            final isSelected = selected.contains(slot);
                            final isWeekend = wd >= 5;

                            return Expanded(
                              child: GestureDetector(
                                onTap: () => onToggle(slot),
                                behavior: HitTestBehavior.opaque,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  margin: EdgeInsets.all(compact ? 1.5 : 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? NebulaColors.stellarBlue
                                            .withValues(alpha: 0.28)
                                        : isWeekend
                                            ? NebulaColors.nebulaPurple
                                                .withValues(alpha: 0.04)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                    border: isSelected
                                        ? Border.all(
                                            color: NebulaColors.stellarBlue
                                                .withValues(alpha: 0.7),
                                            width: 1.2,
                                          )
                                        : null,
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: NebulaColors.stellarBlue
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 6,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: isSelected
                                      ? const Center(
                                          child: Icon(
                                            Icons.check_rounded,
                                            color: NebulaColors.stellarBlue,
                                            size: 14,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Preview section
// ─────────────────────────────────────────────────────────────────────────────

class _PreviewSection extends StatelessWidget {
  final List<DateTime> preview;
  final String monthLabel;
  final bool isForeign;

  const _PreviewSection({
    required this.preview,
    required this.monthLabel,
    required this.isForeign,
  });

  @override
  Widget build(BuildContext context) {
    // Group dates by weekday name for compact display
    final Map<String, List<DateTime>> byDay = {};
    for (final dt in preview) {
      final label = DateFormat('EEEE', 'ru').format(dt);
      byDay.putIfAbsent(label, () => []).add(dt);
    }

    return NebulaSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: NebulaTokens.radiusMD,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.preview_rounded,
                color: NebulaColors.stellarBlue, size: 16),
            const SizedBox(width: 8),
            Text(
              'ПРЕДПРОСМОТР · $monthLabel',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: NebulaColors.stellarBlue,
                letterSpacing: 0.8,
              ),
            ),
          ]),
          const SizedBox(height: 12),

          ...byDay.entries.map((entry) {
            final dayName = entry.key;
            final dates = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_capitalize(dayName)}  ·  ${dates.length} урок${_plural(dates.length)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: NebulaColors.softWhite,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: dates.map((dt) {
                      final label =
                          '${dt.day} ${_shortMonth(dt.month)}  ${DateFormat('HH:mm').format(dt)}';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color:
                              NebulaColors.stellarBlue.withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(NebulaTokens.radiusSM),
                          border: Border.all(
                              color: NebulaColors.stellarBlue
                                  .withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                              fontSize: 12, color: NebulaColors.stellarBlue),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          }),

          const Divider(color: NebulaColors.surfaceBorder, height: 20),

          // Totals row
          Row(children: [
            _Total(
                icon: Icons.calendar_today_rounded,
                label: 'Уроков всего',
                value: '${preview.length}',
                color: NebulaColors.stellarBlue),
            const SizedBox(width: 12),
            if (isForeign)
              const _Total(
                  icon: Icons.language_rounded,
                  label: 'Тариф',
                  value: 'Иностранный',
                  color: NebulaColors.warningAmber)
            else
              const _Total(
                  icon: Icons.person_rounded,
                  label: 'Тариф',
                  value: 'Стандартный',
                  color: NebulaColors.successMint),
          ]),
        ],
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _plural(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'а';
    }
    return 'ов';
  }

  static String _shortMonth(int m) {
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек'
    ];
    return months[m - 1];
  }
}

class _Total extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _Total(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: NebulaColors.ghostText)),
              Text(value,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Confirm button
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmButton extends StatefulWidget {
  final int count;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _ConfirmButton({
    required this.count,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<_ConfirmButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.count > 0
        ? 'Создать ${widget.count} урок${_pl(widget.count)}'
        : 'Выберите слоты';

    return GestureDetector(
      onTapDown: widget.enabled ? (_) => _ctrl.forward() : null,
      onTapUp: widget.enabled
          ? (_) {
              _ctrl.reverse();
              widget.onTap();
            }
          : null,
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            gradient: widget.enabled
                ? const LinearGradient(
                    colors: [
                      NebulaColors.stellarBlue,
                      NebulaColors.nebulaPurple
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            color: widget.enabled ? null : NebulaColors.depthNear,
            borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
            boxShadow: widget.enabled
                ? [
                    BoxShadow(
                      color: NebulaColors.stellarBlue.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: Offset.zero,
                    )
                  ]
                : null,
          ),
          child: Center(
            child: widget.loading
                ? const OrbitLoader(size: 22)
                : Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: widget.enabled
                          ? Colors.white
                          : NebulaColors.ghostText,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  static String _pl(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'а';
    }
    return 'ов';
  }
}
