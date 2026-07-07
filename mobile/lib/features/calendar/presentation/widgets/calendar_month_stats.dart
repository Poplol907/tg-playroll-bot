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

    final type = NebulaTypography.of(context);
    return NebulaSurface(
      padding: const EdgeInsets.all(NebulaTokens.sp20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Статистика месяца',
            style: type.titleS.copyWith(color: tokens.primaryText),
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
          const SizedBox(height: NebulaTokens.sp12),
          // Легенда кодов сетки, которых нет в чипах выше (P2 из critique):
          // цвет ↔ смысл больше не нужно вспоминать.
          const Wrap(
            spacing: NebulaTokens.sp16,
            runSpacing: NebulaTokens.sp4,
            children: [
              _LegendDot(label: 'Отработка', color: NebulaColors.nebulaPurple),
              _LegendDot(
                  label: 'Не заполнен',
                  color: NebulaColors.warningAmber,
                  glyph: '?'),
              _LegendDot(label: 'Сегодня', color: NebulaColors.auroraCyan),
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
    final type = NebulaTypography.of(context);
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
              style: type.titleM.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: type.labelS.copyWith(color: tokens.mutedText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  final String? glyph;

  const _LegendDot({required this.label, required this.color, this.glyph});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        glyph != null
            ? Text(
                glyph!,
                style: type.labelS.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              )
            : Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
        const SizedBox(width: NebulaTokens.sp4),
        Text(label, style: type.labelS.copyWith(color: tokens.mutedText)),
      ],
    );
  }
}
