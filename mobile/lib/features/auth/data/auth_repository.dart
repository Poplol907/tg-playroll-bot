import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
import '../../../shared/models/user.dart';

const _kUserId      = 'cached_user_id';
const _kUserOrgId   = 'cached_user_org_id';
const _kUserLogin   = 'cached_user_login';
const _kUserRole    = 'cached_user_role';
const _kUserName    = 'cached_user_name';

class AuthRepository {
  final Dio _dio;
  final ApiClient _client;

  AuthRepository(this._dio, this._client);

  Future<UserModel> login(String login, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'login': login,
      'password': password,
    });

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid login response format');
    }

    final token = data['access_token'];
    if (token is! String) {
      throw Exception('access_token missing in login response');
    }

    await _client.saveToken(token);
    final user = await me();
    await cacheUser(user);   // сохраняем для offline-старта
    return user;
  }

  Future<UserModel> me() async {
    final response = await _dio.get('/auth/me');
    final data = response.data;

    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid /auth/me response format');
    }

    return UserModel.fromJson(data);
  }

  /// Кешировать данные пользователя в AppStorage для offline-старта.
  Future<void> cacheUser(UserModel user) async {
    final storage = AppStorage.instance;
    await Future.wait([
      storage.write(_kUserId,    user.id.toString()),
      storage.write(_kUserOrgId, user.orgId.toString()),
      storage.write(_kUserLogin, user.login),
      storage.write(_kUserRole,  user.role),
      if (user.teacherName != null)
        storage.write(_kUserName, user.teacherName!),
    ]);
  }

  /// Вернуть закешированного пользователя (или null если кеша нет).
  Future<UserModel?> getCachedUser() async {
    final storage = AppStorage.instance;
    final id    = await storage.read(_kUserId);
    final orgId = await storage.read(_kUserOrgId);
    final login = await storage.read(_kUserLogin);
    final role  = await storage.read(_kUserRole);

    if (id == null || orgId == null || login == null || role == null) return null;

    final parsedId    = int.tryParse(id);
    final parsedOrgId = int.tryParse(orgId);
    if (parsedId == null || parsedOrgId == null) return null;

    return UserModel(
      id: parsedId,
      orgId: parsedOrgId,
      login: login,
      role: role,
      teacherName: await storage.read(_kUserName),
    );
  }

  /// Очистить кеш пользователя (при выходе).
  Future<void> clearCachedUser() async {
    final storage = AppStorage.instance;
    await Future.wait([
      storage.delete(_kUserId),
      storage.delete(_kUserOrgId),
      storage.delete(_kUserLogin),
      storage.delete(_kUserRole),
      storage.delete(_kUserName),
    ]);
  }

  Future<void> logout() async {
    await Future.wait([
      _client.clearToken(),
      clearCachedUser(),
    ]);
  }

  Future<bool> isLoggedIn() async {
    final token = await _client.getToken();
    return token != null;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(apiClientProvider),
  );
});
