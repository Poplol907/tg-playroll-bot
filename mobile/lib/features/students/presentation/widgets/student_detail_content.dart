part of 'student_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────

class _ContentLoader extends ConsumerWidget {
  final StudentModel student;
  final ScrollController scrollCtrl;
  final bool showAllLessons;
  final VoidCallback onToggleAll;
  final double bottomPad;

  const _ContentLoader({
    required this.student,
    required this.scrollCtrl,
    required this.showAllLessons,
    required this.onToggleAll,
    required this.bottomPad,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(studentLessonsProvider(student.id));
    final subsAsync = ref.watch(studentSubscriptionsProvider(student.id));
    final activeMonth = ref.watch(globalMonthYearProvider);

    return lessonsAsync.when(
      loading: () => const Center(child: OrbitLoader()),
      error: (_, __) => const Center(
        child: Text(
          'Не удалось загрузить',
          style: TextStyle(
            color: NebulaColors.ghostText,
          ),
        ),
      ),
      data: (lessons) {
        final subs = subsAsync.valueOrNull ?? const [];
        // Prefer studentTeacherId from the student model itself (returned by
        // backend when the caller is a TEACHER). Fall back to the first lesson
        // if it wasn't in the student payload (e.g., admin view).
        final studentTeacherId = student.studentTeacherId ??
            (lessons.isNotEmpty ? lessons.first.studentTeacherId : null);
        return _Body(
          student: student,
          lessons: lessons,
          subs: subs,
          scrollCtrl: scrollCtrl,
          showAllLessons: showAllLessons,
          onToggleAll: onToggleAll,
          bottomPad: bottomPad,
          activeMonth: activeMonth,
          studentTeacherId: studentTeacherId,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final StudentModel student;
  final List<LessonModel> lessons;
  final List<Map<String, dynamic>> subs;
  final ScrollController scrollCtrl;
  final bool showAllLessons;
  final VoidCallback onToggleAll;
  final double bottomPad;
  final String activeMonth;
  final int? studentTeacherId;

  const _Body({
    required this.student,
    required this.lessons,
    required this.subs,
    required this.scrollCtrl,
    required this.showAllLessons,
    required this.onToggleAll,
    required this.bottomPad,
    required this.activeMonth,
    this.studentTeacherId,
  });

  @override
  Widget build(BuildContext context) {
    // Filter to the currently selected month for stats and history
    final monthLessons = lessons
        .where(
            (l) => DateFormat('yyyy-MM').format(l.scheduledDate) == activeMonth)
        .toList();

    final attended = monthLessons.where((l) => l.status == 'attended').length;
    final missed = monthLessons.where((l) => l.status == 'missed').length;
    final cancelled = monthLessons.where((l) => l.status == 'cancelled').length;
    final scheduled = monthLessons.where((l) => l.status == 'scheduled').length;
    final schedule =
        _weeklySchedule(lessons); // all lessons for pattern detection

    return SingleChildScrollView(
      controller: scrollCtrl,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPad + 52),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subs.isNotEmpty) ...[
            _label('Абонемент'),
            const SizedBox(height: 10),
            _SubscriptionBlock(
                subscriptions: subs,
                lessons: lessons,
                currentMonth: activeMonth),
            const SizedBox(height: 22),
          ],

          _label('Статистика'),
          const SizedBox(height: 10),
          Row(children: [
            _StatTile(
                label: 'Проведено',
                value: '$attended',
                color: NebulaColors.successMint),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Пропуски',
                value: '$missed',
                color: NebulaColors.errorRose),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Отменено',
                value: '$cancelled',
                color: NebulaColors.warningAmber),
            const SizedBox(width: 8),
            _StatTile(
                label: 'Впереди',
                value: '$scheduled',
                color: NebulaColors.stellarBlue),
          ]),
          const SizedBox(height: 22),

          _label('Расписание'),
          const SizedBox(height: 10),
          if (schedule.isEmpty)
            const Text('Расписание не определено',
                style: TextStyle(color: NebulaColors.ghostText, fontSize: 14))
          else
            NebulaSurface(
              padding: const EdgeInsets.all(16),
              borderRadius: NebulaTokens.radiusMD,
              child: Column(
                children: schedule
                    .map((s) =>
                        _ScheduleRow(day: s.day, time: s.time, count: s.count))
                    .toList(),
              ),
            ),
          const SizedBox(height: 22),

          // ── Add schedule button ─────────────────────────────────────
          if (studentTeacherId != null)
            _AddScheduleButton(
              student: student,
              studentTeacherId: studentTeacherId!,
            ),
          if (studentTeacherId != null) const SizedBox(height: 10),

          // ── Lesson history toggle ───────────────────────────────────
          GestureDetector(
            onTap: onToggleAll,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: NebulaColors.stellarBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
                border: Border.all(
                    color: NebulaColors.stellarBlue.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    showAllLessons
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.list_alt_rounded,
                    color: NebulaColors.stellarBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    showAllLessons
                        ? 'Скрыть историю'
                        : 'История · ${_formatMonth(activeMonth)}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: NebulaColors.stellarBlue),
                  ),
                ],
              ),
            ),
          ),

          if (showAllLessons) ...[
            const SizedBox(height: 20),
            _label('История · ${_formatMonth(activeMonth)}'),
            const SizedBox(height: 10),
            if (monthLessons.isEmpty)
              const Text(
                'Уроков в этом месяце нет',
                style: TextStyle(
                  color: NebulaColors.ghostText,
                ),
              )
            else
              ...monthLessons.reversed.map((l) => _LessonRow(lesson: l)),
          ],
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: NebulaColors.ghostText,
          letterSpacing: 0.9,
        ),
      );

  List<_SE> _weeklySchedule(List<LessonModel> lessons) {
    final Map<String, int> counts = {};
    for (final l in lessons) {
      if (l.scheduledTime == null) continue;
      final wd = _wdName(l.scheduledDate.weekday);
      final key = '$wd|${l.scheduledTime}';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final entries = counts.entries.where((e) => e.value >= 2).map((e) {
      final p = e.key.split('|');
      return _SE(day: p[0], time: p[1], count: e.value);
    }).toList();
    const order = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    entries
        .sort((a, b) => order.indexOf(a.day).compareTo(order.indexOf(b.day)));
    return entries;
  }

  String _wdName(int wd) {
    const n = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return n[(wd - 1).clamp(0, 6)];
  }

  String _formatMonth(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
      return DateFormat('MMMM', 'ru').format(dt);
    } catch (_) {
      return yyyyMM;
    }
  }
}

class _SE {
  final String day, time;
  final int count;
  _SE({required this.day, required this.time, required this.count});
}
