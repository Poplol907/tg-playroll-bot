import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/models/user.dart';
import '../../data/auth_repository.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  AuthState copyWith({AuthStatus? status, UserModel? user, String? error}) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        error: error,
      );

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.authenticated;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthNotifier(this._repo)
      : super(const AuthState(status: AuthStatus.initial)) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final loggedIn = await _repo.isLoggedIn();
    if (!mounted) return;

    if (!loggedIn) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      // Пробуем получить актуальные данные с сервера
      final user = await _repo.me();
      if (!mounted) return;
      await _repo.cacheUser(user);   // обновляем кеш при успехе
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on Exception catch (e) {
      if (!mounted) return;

      // Проверяем: это проблема с токеном (401/403) или с сетью?
      final isAuthError = e is DioException &&
          (e.response?.statusCode == 401 || e.response?.statusCode == 403);

      if (isAuthError) {
        // Токен невалиден — нужно войти заново
        await _repo.logout();
        if (!mounted) return;
        state = const AuthState(status: AuthStatus.unauthenticated);
        return;
      }

      // Нет сети / таймаут / 5xx — загружаем закешированного пользователя.
      // Пользователь попадает в приложение с последними известными данными,
      // а не на экран логина. При восстановлении сети провайдеры обновятся сами.
      final cached = await _repo.getCachedUser();
      if (!mounted) return;
      state = AuthState(
        status: cached != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
        user: cached,
      );
    }
  }

  Future<void> login(String login, String password) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final user = await _repo.login(login, password);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on Exception catch (e) {
      state = AuthState(
        status: AuthStatus.error,
        error: _parseError(e),
      );
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _parseError(Exception e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401) return 'Неверный логин или пароль';
      if (code == 403) return 'Доступ запрещён';
      if (e.response == null) return 'Нет соединения с сервером. Проверьте интернет.';
    }
    return 'Произошла ошибка. Попробуйте снова.';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

// Convenience
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
