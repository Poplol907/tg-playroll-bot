import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/payout_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buildPayoutSummary lists each teacher with payout + a studio total',
      () {
    const stats = StudioStats(
      month: '2026-06',
      totalLessonsDone: 20,
      totalLessonsMissed: 0,
      totalLessonsCancelled: 0,
      totalLessonsScheduled: 0,
      activeStudents: 5,
      activeTeachers: 2,
      teachers: [
        TeacherStats(
          teacherId: 1,
          teacherName: 'Аня',
          lessonsDone: 12,
          lessonsMissed: 0,
          lessonsDebt: 0,
          lessonsCancelledMakeup: 0,
          totalAmount: 48000,
        ),
        TeacherStats(
          teacherId: 2,
          teacherName: 'Олег',
          lessonsDone: 8,
          lessonsMissed: 0,
          lessonsDebt: 0,
          lessonsCancelledMakeup: 0,
          totalAmount: 32000,
        ),
      ],
    );

    final text = buildPayoutSummary(stats);

    expect(text, contains('2026-06'));
    expect(text, contains('Аня'));
    expect(text, contains('Олег'));
    expect(text, contains('48')); // 48 000 сум
    expect(text, contains('80')); // total 80 000
  });
}
