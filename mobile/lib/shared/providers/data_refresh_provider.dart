import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/calendar/presentation/providers/calendar_provider.dart';
import '../../features/salary/presentation/providers/salary_provider.dart';
import '../../features/students/data/students_repository.dart';
import '../../features/students/presentation/providers/student_lessons_provider.dart';

/// Refreshes all cached views that derive from lesson facts for a month.
///
/// Use this after lesson mutations instead of manually invalidating calendar,
/// salary, and student-card providers in each screen.
void invalidateMonthData(
  WidgetRef ref,
  String monthYear, {
  Iterable<String> extraMonthYears = const [],
}) {
  final months = <String>{monthYear, ...extraMonthYears};
  for (final month in months) {
    ref.invalidate(lessonsProvider(month));
  }

  ref.invalidate(salaryProvider);
  ref.invalidate(studentsProvider);
  ref.invalidate(studentLessonsProvider);
  ref.invalidate(studentSubscriptionsProvider);
}
