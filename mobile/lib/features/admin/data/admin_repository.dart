import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/providers/month_provider.dart';

// ── Models ────────────────────────────────────────────────────────────────────

/// Per-teacher monthly stats from /reports/studio
class TeacherStats {
  final int teacherId;
  final String teacherName;
  final int lessonsDone;
  final int lessonsMissed;
  final int lessonsDebt;
  final int lessonsCancelledMakeup;
  final int totalAmount;

  const TeacherStats({
    required this.teacherId,
    required this.teacherName,
    required this.lessonsDone,
    required this.lessonsMissed,
    required this.lessonsDebt,
    required this.lessonsCancelledMakeup,
    required this.totalAmount,
  });

  factory TeacherStats.fromJson(Map<String, dynamic> j) => TeacherStats(
        teacherId: j['teacher_id'] as int,
        teacherName: (j['teacher_name'] as String?) ?? 'Без имени',
        lessonsDone: j['lessons_done'] as int? ?? 0,
        lessonsMissed: j['lessons_missed'] as int? ?? 0,
        lessonsDebt: j['lessons_debt'] as int? ?? 0,
        lessonsCancelledMakeup: j['lessons_cancelled_makeup'] as int? ?? 0,
        totalAmount: j['total_amount'] as int? ?? 0,
      );
}

/// Aggregated stats for the whole studio.
class StudioStats {
  final String month;
  final int totalLessonsDone;
  final int totalLessonsMissed;
  final int totalLessonsCancelled;
  final int totalLessonsScheduled;
  final int activeStudents;
  final int activeTeachers;
  final List<TeacherStats> teachers;

  const StudioStats({
    required this.month,
    required this.totalLessonsDone,
    required this.totalLessonsMissed,
    required this.totalLessonsCancelled,
    required this.totalLessonsScheduled,
    required this.activeStudents,
    required this.activeTeachers,
    required this.teachers,
  });

  /// Суммарный заработок студии за месяц.
  int get totalAmount =>
      teachers.fold(0, (sum, t) => sum + t.totalAmount);

  factory StudioStats.fromJson(Map<String, dynamic> j) => StudioStats(
        month: j['month'] as String,
        totalLessonsDone: j['total_lessons_done'] as int? ?? 0,
        totalLessonsMissed: j['total_lessons_missed'] as int? ?? 0,
        totalLessonsCancelled: j['total_lessons_cancelled'] as int? ?? 0,
        totalLessonsScheduled: j['total_lessons_scheduled'] as int? ?? 0,
        activeStudents: j['active_students'] as int? ?? 0,
        activeTeachers: j['active_teachers'] as int? ?? 0,
        teachers: (j['teachers'] as List? ?? [])
            .map((e) => TeacherStats.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class OrgUser {
  final int id;
  final String login;
  final String role;
  final String? teacherName;
  final bool hasPassword;

  const OrgUser({
    required this.id,
    required this.login,
    required this.role,
    this.teacherName,
    required this.hasPassword,
  });

  factory OrgUser.fromJson(Map<String, dynamic> j) => OrgUser(
        id: j['id'] as int,
        login: j['login'] as String,
        role: j['role'] as String,
        teacherName: j['teacher_name'] as String?,
        hasPassword: j['has_password'] as bool? ?? false,
      );

  String get displayName => teacherName ?? login;
  bool get isAdmin => role == 'ADMIN';
}

// ── Repository ────────────────────────────────────────────────────────────────

class AdminRepository {
  final Dio _dio;
  AdminRepository(this._dio);

  Future<List<OrgUser>> getUsers() async {
    final r = await _dio.get('/org/users');
    return (r.data as List).map((e) => OrgUser.fromJson(e)).toList();
  }

  Future<OrgUser> createUser({
    required String login,
    required String role,
    String? teacherName,
    String? password,
  }) async {
    final r = await _dio.post('/org/users', data: {
      'login': login,
      'role': role,
      if (teacherName != null && teacherName.isNotEmpty)
        'teacher_name': teacherName,
      if (password != null && password.isNotEmpty) 'password': password,
    });
    return OrgUser.fromJson(r.data);
  }

  Future<void> setPassword(int userId, String password) async {
    await _dio.post('/org/users/$userId/password', data: {'password': password});
  }

  Future<void> deleteUser(int userId) async {
    await _dio.delete('/org/users/$userId');
  }

  Future<StudioStats> getStudioStats(String monthYear) async {
    final r = await _dio.get('/reports/studio', queryParameters: {
      'month': monthYear,
    });
    return StudioStats.fromJson(r.data as Map<String, dynamic>);
  }
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);

final orgUsersProvider = FutureProvider<List<OrgUser>>((ref) {
  return ref.watch(adminRepositoryProvider).getUsers();
});

final studioStatsProvider = FutureProvider<StudioStats>((ref) {
  final monthYear = ref.watch(globalMonthYearProvider);
  return ref.watch(adminRepositoryProvider).getStudioStats(monthYear);
});
