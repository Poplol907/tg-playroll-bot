import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/models/lesson.dart';
import '../../../admin/presentation/providers/view_as_teacher_provider.dart';

// Загружает все уроки конкретного ученика (без фильтра по месяцу)
final studentLessonsProvider =
    FutureProvider.family<List<LessonModel>, int>((ref, studentId) async {
  final dio = ref.watch(dioProvider);
  final viewAs = ref.watch(viewAsTeacherProvider);
  final response = await dio.get('/lessons', queryParameters: {
    'student_id': studentId,
    if (viewAs != null) 'teacher_id': viewAs.id,
  });
  final data = response.data as List<dynamic>;
  final lessons =
      data.map((e) => LessonModel.fromJson(e as Map<String, dynamic>)).toList();
  // Сортируем от новых к старым
  lessons.sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));
  return lessons;
});

// Загружает абонементы ученика
final studentSubscriptionsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, int>(
        (ref, studentId) async {
  final dio = ref.watch(dioProvider);
  final viewAs = ref.watch(viewAsTeacherProvider);
  final response = await dio.get('/subscriptions', queryParameters: {
    'student_id': studentId,
    if (viewAs != null) 'teacher_id': viewAs.id,
  });
  final data = response.data as List<dynamic>;
  return data.cast<Map<String, dynamic>>();
});
