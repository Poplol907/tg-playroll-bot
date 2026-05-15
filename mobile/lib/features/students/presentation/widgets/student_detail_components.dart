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
  final SemanticIntent intent;
  const _StatTile(
      {required this.label, required this.value, required this.intent});

  @override
  Widget build(BuildContext context) {
    final role = NebulaSemantic.of(context).byIntent(intent);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: role.base.withValues(alpha: NebulaAlpha.mist),
          borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
          border: Border.all(
              color: role.base.withValues(alpha: NebulaAlpha.border)),
        ),
        child: Column(children: [
          Center(child: MetricStat(label: label, value: value, intent: intent)),
        ]),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final type = NebulaTypography.of(context);
    final role = NebulaSemantic.of(context).primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: role.tint,
            borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
            border: Border.all(color: role.border),
          ),
          child: Center(
            child: Text(day,
                style: type.labelM.copyWith(
                    color: role.contrast, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 12),
        Text(time,
            style: type.titleS.copyWith(color: NebulaColors.softWhite)),
        const Spacer(),
        Text('$count ${_word(count)}',
            style: type.labelM.copyWith(color: NebulaColors.ghostText)),
      ]),
    );
  }
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

    final type = NebulaTypography.of(context);
    return NebulaSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: NebulaTokens.radiusMD,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(monthName,
              style: type.titleS.copyWith(color: NebulaColors.softWhite)),
          const Spacer(),
          StatusBadge(
            label: status == 'active' ? 'Активен' : status,
            intent: status == 'active'
                ? SemanticIntent.success
                : SemanticIntent.warning,
            styleOverride: BadgeStyle.compact,
          ),
        ]),
        const SizedBox(height: 14),
        _ProgressBar(done: done, missed: missed, paid: paid),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: Center(
                  child: MetricStat(
                      label: 'Куплено',
                      value: '$paid',
                      intent: SemanticIntent.primary))),
          Expanded(
              child: Center(
                  child: MetricStat(
                      label: 'Проведено',
                      value: '$done',
                      intent: SemanticIntent.success))),
          Expanded(
              child: Center(
                  child: MetricStat(
                      label: 'Пропуски',
                      value: '$missed',
                      intent: SemanticIntent.danger))),
          Expanded(
              child: Center(
                  child: MetricStat(
                      label: 'Осталось',
                      value: '$remaining',
                      intent: SemanticIntent.info))),
        ]),
        if (ml.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Divider(color: NebulaColors.surfaceBorder, height: 1),
          const SizedBox(height: 12),
          Text('Купленные даты',
              style: type.labelM.copyWith(color: NebulaColors.ghostText)),
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
              style: type.labelM.copyWith(color: NebulaColors.stellarBlue)),
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


class _DateChip extends StatelessWidget {
  final LessonModel lesson;
  const _DateChip({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final color = lesson.statusColor;
    final type = NebulaTypography.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: NebulaAlpha.surface),
        borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
        border: Border.all(color: color.withValues(alpha: NebulaAlpha.accent)),
      ),
      child: Column(children: [
        Text('${lesson.scheduledDate.day}',
            style: type.bodyM
                .copyWith(color: color, fontWeight: FontWeight.w700)),
        Text(DateFormat('EE', 'ru').format(lesson.scheduledDate),
            style: type.overline.copyWith(color: NebulaColors.ghostText)),
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

    final type = NebulaTypography.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: NebulaAlpha.whisper),
          borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
          border: Border.all(color: color.withValues(alpha: NebulaAlpha.border)),
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
                style: type.bodyM.copyWith(color: NebulaColors.softWhite)),
          ),
          if (lesson.scheduledTime != null)
            Text(lesson.scheduledTime!,
                style: type.labelM.copyWith(color: NebulaColors.dimText)),
          const SizedBox(width: 10),
          Text(label, style: type.labelM.copyWith(color: color)),
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
              NebulaColors.stellarBlue.withValues(alpha: NebulaAlpha.surface),
              NebulaColors.nebulaPurple.withValues(alpha: NebulaAlpha.mist),
            ],
          ),
          borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
          border: Border.all(
            color: NebulaColors.stellarBlue.withValues(alpha: NebulaAlpha.accent),
          ),
          boxShadow: [
            BoxShadow(
              color: NebulaColors.stellarBlue.withValues(alpha: NebulaAlpha.mist),
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
                color: NebulaColors.stellarBlue
                    .withValues(alpha: NebulaAlpha.subtle),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.calendar_month_rounded,
                color: NebulaColors.stellarBlue,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Добавить расписание',
              style: NebulaTypography.of(context)
                  .titleS
                  .copyWith(color: NebulaColors.stellarBlue),
            ),
          ],
        ),
      ),
    );
  }
}
