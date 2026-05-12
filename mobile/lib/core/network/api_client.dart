import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/app_storage.dart';
import 'server_config.dart';

const String _tokenKey = 'auth_token';

class ApiClient {
  late final Dio _dio;

  ApiClient(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(_AuthInterceptor());
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  Dio get dio => _dio;

  Future<void> saveToken(String token) =>
      AppStorage.instance.write(_tokenKey, token);

  Future<String?> getToken() => AppStorage.instance.read(_tokenKey);

  Future<void> clearToken() => AppStorage.instance.delete(_tokenKey);
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await AppStorage.instance.read(_tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      AppStorage.instance.delete(_tokenKey);
    }
    handler.next(err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Providers
//  ApiClient пересоздаётся автоматически при изменении serverUrlProvider
// ─────────────────────────────────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) {
  final url = ref.watch(serverUrlProvider);
  return ApiClient(url);
});

final dioProvider = Provider<Dio>((ref) => ref.watch(apiClientProvider).dio);
