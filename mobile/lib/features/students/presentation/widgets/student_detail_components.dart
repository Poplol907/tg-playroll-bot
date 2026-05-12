part of 'student_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Subwidgets
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final StudentModel student;
  final double size;
  const _Avatar({required this.student, required this.size});

  LinearGradient get _g {
    const gs = [
      [NebulaColors.stellarBlue, NebulaColors.nebulaPurple],
      [NebulaColors.nebulaPurple, NebulaColors.errorRose],
      [NebulaColors.successMint, NebulaColors.stellarBlue],
      [NebulaColors.warningAmber, NebulaColors.errorRose],
      [NebulaColors.stellarBlue, NebulaColors.auroraCyan],
      [NebulaColors.nebulaPurple, NebulaColors.warningAmber],
    ];
    return LinearGradient(
        colors: gs[student.id % 6],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight);
  }

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(gradient: _g, shape: BoxShape.circle),
        child: Center(
          child: Text(student.initials,
              style: TextStyle(
                  fontSize: size * 0.33,
                  fontWeight: FontWeight.w700,
                  color: Colors.black)),
        ),
      );
}

class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatTile(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: NebulaColors.ghostText)),
          ]),
        ),
      );
}

class _ScheduleRow extends StatelessWidget {
  final String day, time;
  final int count;
  const _ScheduleRow(
      {required this.day, required this.time, required this.count});

  String _word(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'урок';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'урока';
    }
    return 'уроков';
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: NebulaColors.stellarBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
              border: Border.all(
                  color: NebulaColors.stellarBlue.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(day,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: NebulaColors.stellarBlue)),
            ),
          ),
          const SizedBox(width: 12),
          Text(time,
              style:
                  const TextStyle(fontSize: 15, color: NebulaColors.softWhite)),
          const Spacer(),
          Text('$count ${_word(count)}',
              style:
                  const TextStyle(fontSize: 12, color: NebulaColors.ghostText)),
        ]),
      );
}

class _SubscriptionBlock extends StatelessWidget {
  final List<Map<String, dynamic>> subscriptions;
  final List<LessonModel> lessons;
  final String currentMonth;

  const _SubscriptionBlock(
      {required this.subscriptions,
      required this.lessons,
      required this.currentMonth});

  @override
  Widget build(BuildContext context) {
    final sub = subscriptions.firstWhere(
      (s) => s['month_year'] == currentMonth,
      orElse: () => subscriptions.first,
    );
    final month = sub['month_year'] as String;
    final paid = (sub['lessons_count'] as num).toInt();
    final status = sub['status'] as String? ?? 'active';
    final ml = lessons.where((l) {
      final ym =
          '${l.scheduledDate.year}-${l.scheduledDate.month.toString().padLeft(2, '0')}';
      return ym == month;
    }).toList();
    final done = ml.where((l) => l.status == 'attended').length;
    final missed = ml.where((l) => l.status == 'missed').length;
    final remaining = paid - done - missed;
    final parts = month.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final monthName = DateFormat('MMMM yyyy', 'ru').format(dt);

    return NebulaSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: NebulaTokens.radiusMD,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(monthName,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: NebulaColors.softWhite)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: status == 'active'
                  ? NebulaColors.successMint.withValues(alpha: 0.12)
                  : NebulaColors.warningAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(NebulaTokens.radiusXS),
              border: Border.all(
                  color: status == 'active'
                      ? NebulaColors.successMint.withValues(alpha: 0.3)
                      : NebulaColors.warningAmber.withValues(alpha: 0.3)),
            ),
            child: Text(
              status == 'active' ? 'Активен' : status,
              style: TextStyle(
                  fontSize: 11,
                  color: status == 'active'
                      ? NebulaColors.successMint
                      : NebulaColors.warningAmber),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _ProgressBar(done: done, missed: missed, paid: paid),
        const SizedBox(height: 12),
        Row(children: [
          _SubStat('Куплено', '$paid', NebulaColors.stellarBlue),
          _SubStat('Проведено', '$done', NebulaColors.successMint),
          _SubStat('Пропуски', '$missed', NebulaColors.errorRose),
          _SubStat('Осталось', '$remaining', NebulaColors.nebulaPurple),
        ]),
        if (ml.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(color: NebulaColors.surfaceBorder, height: 1),
          const SizedBox(height: 12),
          const Text('Купленные даты',
              style: TextStyle(fontSize: 12, color: NebulaColors.ghostText)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: (List<LessonModel>.from(ml)
                  ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate)))
                .map((l) => _DateChip(lesson: l))
                .toList(),
          ),
        ],
        if (subscriptions.length > 1) ...[
          const SizedBox(height: 12),
          Text('Всего абонементов: ${subscriptions.length}',
              style: const TextStyle(
                  fontSize: 12, color: NebulaColors.stellarBlue)),
        ],
      ]),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int done, missed, paid;
  const _ProgressBar(
      {required this.done, required this.missed, required this.paid});

  @override
  Widget build(BuildContext context) {
    final total = paid == 0 ? 1 : paid;
    final dF = (done / total).clamp(0.0, 1.0);
    final mF = (missed / total).clamp(0.0, 1.0 - dF);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Stack(children: [
        Container(height: 6, color: NebulaColors.surfaceBorder),
        FractionallySizedBox(
            widthFactor: dF,
            child: Container(height: 6, color: NebulaColors.successMint)),
        FractionallySizedBox(
          widthFactor: dF + mF,
          child: Container(
            height: 6,
            decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
              NebulaColors.successMint,
              NebulaColors.errorRose
            ])),
          ),
        ),
      ]),
    );
  }
}

class _SubStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SubStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 10, color: NebulaColors.ghostText)),
        ]),
      );
}

class _DateChip extends StatelessWidget {
  final LessonModel lesson;
  const _DateChip({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final color = lesson.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text('${lesson.scheduledDate.day}',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        Text(DateFormat('EE', 'ru').format(lesson.scheduledDate),
            style:
                const TextStyle(fontSize: 10, color: NebulaColors.ghostText)),
      ]),
    );
  }
}

class _LessonRow extends StatelessWidget {
  final LessonModel lesson;
  const _LessonRow({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final color = lesson.statusColor;
    final label = {
          'attended': 'Проведён',
          'missed': 'Пропуск',
          'cancelled': 'Отменён',
          'scheduled': 'Запланирован',
        }[lesson.status] ??
        lesson.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                DateFormat('d MMM yyyy', 'ru').format(lesson.scheduledDate),
                style: const TextStyle(
                    fontSize: 14, color: NebulaColors.softWhite)),
          ),
          if (lesson.scheduledTime != null)
            Text(lesson.scheduledTime!,
                style:
                    const TextStyle(fontSize: 12, color: NebulaColors.dimText)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Add schedule button
// ─────────────────────────────────────────────────────────────────────────────

class _AddScheduleButton extends ConsumerWidget {
  final StudentModel student;
  final int studentTeacherId;

  const _AddScheduleButton({
    required this.student,
    required this.studentTeacherId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final added = await ScheduleBuilderModal.show(
          context,
          student: student,
          studentTeacherId: studentTeacherId,
        );
        if (added) {
          // Providers are already invalidated inside the modal.
          // The parent sheet will rebuild automatically.
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              NebulaColors.stellarBlue.withValues(alpha: 0.12),
              NebulaColors.nebulaPurple.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          border: Border.all(
            color: NebulaColors.stellarBlue.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: NebulaColors.stellarBlue.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: Offset.zero,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: NebulaColors.stellarBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: NebulaColors.stellarBlue,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Добавить расписание',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: NebulaColors.stellarBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
