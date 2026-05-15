import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../features/admin/presentation/providers/view_as_teacher_provider.dart';
import '../../../../shared/providers/month_provider.dart';

class SalaryData {
  final String monthYear;
  final String periodStart;
  final String periodEnd;
  final int goalAmount;
  final int totalSubscribed;
  final int earnedAmount;
  final int pendingAmount;
  final int totalCurrent;
  final int lessonsDone;
  final int lessonsMissed;
  final int lessonsDebt;
  final int lessonsMakeupDone;
  final int advanceAmount;
  final int finalAmount;
  final int totalAmount;

  const SalaryData({
    required this.monthYear,
    required this.periodStart,
    required this.periodEnd,
    required this.goalAmount,
    required this.totalSubscribed,
    required this.earnedAmount,
    required this.pendingAmount,
    required this.totalCurrent,
    required this.lessonsDone,
    required this.lessonsMissed,
    required this.lessonsDebt,
    required this.lessonsMakeupDone,
    required this.advanceAmount,
    required this.finalAmount,
    required this.totalAmount,
  });

  factory SalaryData.fromJson(Map<String, dynamic> j) => SalaryData(
        monthYear: j['month_year'] as String,
        periodStart: j['period_start'] as String,
        periodEnd: j['period_end'] as String,
        goalAmount: j['goal_amount'] as int,
        totalSubscribed: j['total_subscribed'] as int,
        earnedAmount: j['earned_amount'] as int,
        pendingAmount: j['pending_amount'] as int,
        totalCurrent: j['total_current'] as int,
        lessonsDone: j['lessons_done'] as int,
        lessonsMissed: j['lessons_missed'] as int,
        lessonsDebt: j['lessons_debt'] as int,
        lessonsMakeupDone: j['lessons_makeup_done'] as int,
        advanceAmount: j['advance_amount'] as int,
        finalAmount: j['final_amount'] as int,
        totalAmount: j['total_amount'] as int,
      );
}

class RateEntry {
  final int ratePerLesson;
  final bool isForeign;
  final String? instrumentName;
  final String note;

  const RateEntry({
    required this.ratePerLesson,
    this.isForeign = false,
    this.instrumentName,
    required this.note,
  });

  factory RateEntry.fromJson(Map<String, dynamic> j) => RateEntry(
        ratePerLesson: j['rate_per_lesson'] as int,
        isForeign: (j['is_foreign'] as bool?) ?? false,
        instrumentName: j['instrument_name'] as String?,
        note: (j['note'] as String?) ?? '',
      );
}

final salaryProvider = FutureProvider<SalaryData>((ref) async {
  final monthYear = ref.watch(globalMonthYearProvider);
  final viewAs = ref.watch(viewAsTeacherProvider);
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    '/reports/v2/salary',
    queryParameters: {
      'month_year': monthYear,
      if (viewAs != null) 'teacher_id': viewAs.id,
    },
  );
  return SalaryData.fromJson(response.data as Map<String, dynamic>);
});

final ratesProvider = FutureProvider<List<RateEntry>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get('/rates/v2/my');
  final list = response.data as List;
  return list
      .map((e) => RateEntry.fromJson(e as Map<String, dynamic>))
      .toList();
});
