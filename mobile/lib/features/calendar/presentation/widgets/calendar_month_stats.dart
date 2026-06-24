part of '../screens/calendar_screen.dart';

class _MonthStats extends StatelessWidget {
  final List<dynamic> lessons;

  const _MonthStats({required this.lessons});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    // Makeup lessons are the SAME lesson rescheduled — exclude from counts
    // so the total stays at 121, not 121 + number-of-makeups.
    final regular = lessons.where((l) => !(l as LessonModel).isMakeup).toList();
    final attended = regular.where((l) => l.status == 'attended').length;
    final missed = regular.where((l) => l.status == 'missed').length;
    final cancelled = regular.where((l) => l.status == 'cancelled').length;
    final total = regular.length;

    return NebulaSurface(
      padding: const EdgeInsets.all(NebulaTokens.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика месяца',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.primaryText,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatChip(
                  label: 'Всего',
                  value: '$total',
                  color: NebulaColors.stellarBlue),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Проведено',
                  value: '$attended',
                  color: NebulaColors.successMint),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Пропуски',
                  value: '$missed',
                  color: NebulaColors.errorRose),
              const SizedBox(width: 8),
              _StatChip(
                  label: 'Отменено',
                  value: '$cancelled',
                  color: NebulaColors.warningAmber),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: NebulaAlpha.surface),
          borderRadius: NebulaRadii.controlBorder,
          border:
              Border.all(color: color.withValues(alpha: NebulaAlpha.border)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: tokens.mutedText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
