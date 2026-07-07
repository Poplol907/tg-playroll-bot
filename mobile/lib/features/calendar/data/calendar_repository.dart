import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/lesson.dart';

class CalendarRepository {
  final Dio _dio;

  CalendarRepository(this._dio);

  Future<List<LessonModel>> getLessons({
    required String monthYear, // 'YYYY-MM'
    int? teacherId, // опц. — admin view-as
  }) async {
    final response = await _dio.get('/lessons', queryParameters: {
      'month': monthYear,
      if (teacherId != null) 'teacher_id': teacherId,
    });
    final data = response.data as List<dynamic>;
    return data
        .map((e) => LessonModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LessonModel> updateLessonStatus(int lessonId, String status,
      {String? cancelledBy}) async {
    final body = <String, dynamic>{'status': status};
    if (cancelledBy != null) body['cancelled_by'] = cancelledBy;
    final response = await _dio.patch('/lessons/$lessonId/status', data: body);
    return LessonModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteLesson(int lessonId) async {
    await _dio.delete('/lessons/$lessonId');
  }

  Future<LessonModel> createLesson({
    required int studentTeacherId,
    required String scheduledDate,
    String? scheduledTime,
    int? subscriptionId,
  }) async {
    final response = await _dio.post('/lessons', data: {
      'student_teacher_id': studentTeacherId,
      'scheduled_date': scheduledDate,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
      if (subscriptionId != null) 'subscription_id': subscriptionId,
    });
    return LessonModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Bulk-create lessons for a given student_teacher for a full month.
  /// [slots] is a list of {weekday: int, time: "HH:MM"} maps.
  /// Returns the raw response body.
  Future<Map<String, dynamic>> createBulkLessons({
    required int studentTeacherId,
    required String monthYear,
    required List<Map<String, dynamic>> slots,
  }) async {
    final response = await _dio.post('/lessons/bulk', data: {
      'student_teacher_id': studentTeacherId,
      'month_year': monthYear,
      'slots': slots,
    });
    return response.data as Map<String, dynamic>;
  }
}

final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository(ref.watch(dioProvider));
});
