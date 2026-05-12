import 'package:dio/dio.dart';

/// Converts any API/network error into a short, user-friendly Russian string.
///
/// Priority:
/// 1. `detail` string from the JSON response body (set by the backend).
/// 2. HTTP status-code based fallback message.
/// 3. Generic connection/unexpected error.
String parseApiError(Object e, {String? fallback}) {
  if (e is DioException) {
    // 1. Try to read the `detail` field the backend always sends
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }

    // 2. Status-code fallbacks
    switch (e.response?.statusCode) {
      case 400:
        return 'Неверный запрос. Проверьте введённые данные.';
      case 401:
        return 'Сессия истекла. Войдите снова.';
      case 403:
        return 'Нет доступа к этому действию.';
      case 404:
        return 'Запись не найдена.';
      case 409:
        return 'Конфликт: такая запись уже существует.';
      case 422:
        return 'Неверный формат данных. Проверьте поля.';
      case 500:
        return 'Ошибка сервера. Попробуйте позже.';
      case null:
        // No response — connection problem
        return 'Нет соединения с сервером. Проверьте интернет.';
    }
    return 'Ошибка соединения. Попробуйте снова.';
  }

  return fallback ?? 'Что-то пошло не так. Попробуйте снова.';
}
