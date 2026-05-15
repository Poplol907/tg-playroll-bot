import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/lesson.dart';
import '../../../../shared/providers/month_provider.dart';
import '../../../admin/presentation/providers/view_as_teacher_provider.dart';
import '../../data/calendar_repository.dart';

// selectedMonthProvider is now an alias for the global month provider
// so any screen that writes to selectedMonthProvider also affects salary/students.
final selectedMonthProvider = globalMonthProvider;

// Lessons for current month.
// Когда админ в режиме view-as — подмешиваем teacher_id, чтобы сервер
// вернул уроки выбранного педагога, а не текущего пользователя.
final lessonsProvider =
    FutureProvider.family<List<LessonModel>, String>((ref, monthYear) async {
  final repo = ref.watch(calendarRepositoryProvider);
  final viewAs = ref.watch(viewAsTeacherProvider);
  return repo.getLessons(
    monthYear: monthYear,
    teacherId: viewAs?.id,
  );
});

// Derived: lessons for currently selected month
final currentMonthLessonsProvider =
    FutureProvider<List<LessonModel>>((ref) async {
  final month = ref.watch(selectedMonthProvider);
  final monthYear = DateFormat('yyyy-MM').format(month);
  return ref.watch(lessonsProvider(monthYear).future);
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
