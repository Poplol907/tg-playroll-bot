import '../../../core/money/currency.dart';
import '../data/admin_repository.dart';

/// Plain-text monthly payout summary for sharing with an accountant.
String buildPayoutSummary(StudioStats stats) {
  final lines = <String>[
    'Выплаты студии — ${stats.month}',
    '',
  ];
  for (final t in stats.teachers) {
    lines.add(
        '${t.teacherName}: ${Money.format(t.totalAmount)} (${t.lessonsDone} уроков)');
  }
  lines
    ..add('')
    ..add('Итого: ${Money.format(stats.totalAmount)}');
  return lines.join('\n');
}
