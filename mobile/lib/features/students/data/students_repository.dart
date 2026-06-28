import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../features/admin/presentation/providers/view_as_teacher_provider.dart';
import '../../../shared/models/student.dart';

// ── Teacher simple model (for picker) ────────────────────────────────────────

class TeacherPickerItem {
  final int id;
  final String name;
  const TeacherPickerItem({required this.id, required this.name});
}

// ── Repository ────────────────────────────────────────────────────────────────

class StudentsRepository {
  final Dio _dio;

  StudentsRepository(this._dio);

  /// [teacherId] — если задан, возвращает учеников именно этого педагога.
  /// Используется админом в режиме view-as.
  Future<List<StudentModel>> getStudents({int? teacherId}) async {
    final path =
        teacherId != null ? '/students/teacher/$teacherId' : '/students';
    final response = await _dio.get(path);
    final data = response.data as List<dynamic>;
    return data
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StudentModel> createStudent({
    required String firstName,
    required String lastName,
    String? phone,
    bool isForeign = false,
    int? teacherUserId,
  }) async {
    final response = await _dio.post('/students/create', data: {
      'first_name': firstName,
      'last_name': lastName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      'is_foreign': isForeign,
      if (teacherUserId != null) 'teacher_user_id': teacherUserId,
    });
    return StudentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteStudent(int studentId) async {
    await _dio.delete('/students/$studentId');
  }

  Future<List<TeacherPickerItem>> getTeachers() async {
    final response = await _dio.get('/teachers');
    final data = response.data as List<dynamic>;
    return data.map((e) {
      final m = e as Map<String, dynamic>;
      return TeacherPickerItem(
        id: m['id'] as int,
        name: (m['teacher_name'] as String?) ?? (m['login'] as String),
      );
    }).toList();
  }
}

final studentsRepositoryProvider = Provider<StudentsRepository>((ref) {
  return StudentsRepository(ref.watch(dioProvider));
});

final studentsProvider = FutureProvider<List<StudentModel>>((ref) async {
  // В режиме view-as админ видит учеников выбранного педагога.
  final viewAs = ref.watch(viewAsTeacherProvider);
  return ref
      .watch(studentsRepositoryProvider)
      .getStudents(teacherId: viewAs?.id);
});

final teachersPickerProvider = FutureProvider<List<TeacherPickerItem>>((ref) async {
  return ref.watch(studentsRepositoryProvider).getTeachers();
});

/// Students of a specific teacher (admin drill). Keyed by teacher user id.
final studentsByTeacherProvider =
    FutureProvider.family<List<StudentModel>, int>((ref, teacherId) async {
  return ref.watch(studentsRepositoryProvider).getStudents(teacherId: teacherId);
});
