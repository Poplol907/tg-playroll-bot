import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

// ── Models ────────────────────────────────────────────────────────────────────

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
}

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(dioProvider)),
);

final orgUsersProvider = FutureProvider<List<OrgUser>>((ref) {
  return ref.watch(adminRepositoryProvider).getUsers();
});
