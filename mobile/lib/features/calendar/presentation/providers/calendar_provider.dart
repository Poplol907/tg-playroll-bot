import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/lesson.dart';
import '../../../../shared/providers/month_provider.dart';
import '../../../admin/presentation/providers/view_as_teacher_provider.dart';
import '../../data/calendar_repository.dart';

// selectedMonthProvider is now an alias for the global month provider
// so any screen that writes to selectedMonthProvider also affects salary/students.
final selectedMonthProvider = globalMonthProvider;

// Cache key for a month of lessons in a specific teacher context. Including
// teacherId means admin/view-as never shares a cache slot with another teacher
// — eliminates the "lessons of one teacher briefly show for everyone" leak.
typedef LessonsQuery = ({String monthYear, int? teacherId});

// Lessons for a month in an explicit teacher context.
final lessonsProvider =
    FutureProvider.family<List<LessonModel>, LessonsQuery>((ref, query) async {
  final repo = ref.watch(calendarRepositoryProvider);
  return repo.getLessons(
    monthYear: query.monthYear,
    teacherId: query.teacherId,
  );
});

// Derived: lessons for the currently selected month in the current view-as
// context. Synchronous Provider (not FutureProvider) so switching teacher
// returns the new context's AsyncValue immediately instead of lingering on the
// previous teacher's data during the refetch gap.
final currentMonthLessonsProvider =
    Provider<AsyncValue<List<LessonModel>>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final monthYear = DateFormat('yyyy-MM').format(month);
  final viewAs = ref.watch(viewAsTeacherProvider);
  return ref.watch(
    lessonsProvider((monthYear: monthYear, teacherId: viewAs?.id)),
  );
});

// Selected day's lessons
final selectedDayProvider = StateProvider<DateTime?>((ref) => null);

final selectedDayLessonsProvider = Provider<List<LessonModel>>((ref) {
  final day = ref.watch(selectedDayProvider);
  if (day == null) return [];
  final lessons = ref.watch(currentMonthLessonsProvider).valueOrNull ?? [];
  return lessons
      .where((l) =>
          l.scheduledDate.year == day.year &&
          l.scheduledDate.month == day.month &&
          l.scheduledDate.day == day.day)
      .toList();
});
