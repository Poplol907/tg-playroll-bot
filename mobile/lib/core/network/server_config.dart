import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/app_storage.dart';

const _kServerUrlKey = 'server_url';
// Production URL — замени на свой домен после настройки сервера.
// Кнопка шестерёнки на экране логина позволяет переключиться на локальный сервер
// для разработки без пересборки приложения.
const kDefaultServerUrl = 'https://yourdomain.com';

// ─────────────────────────────────────────────────────────────────────────────
//  Notifier — хранит URL сервера, персистит в AppStorage
// ─────────────────────────────────────────────────────────────────────────────

class ServerUrlNotifier extends Notifier<String> {
  @override
  String build() {
    // Синхронный старт с дефолтом, асинхронно загружаем сохранённый URL
    Future.microtask(_loadSaved);
    return kDefaultServerUrl;
  }

  Future<void> _loadSaved() async {
    final saved = await AppStorage.instance.read(_kServerUrlKey);
    if (saved != null && saved.isNotEmpty && _isValidUrl(saved)) {
      state = saved;
    } else if (saved != null && saved.isNotEmpty) {
      // Corrupt/invalid value — clear it and fall back to default
      await AppStorage.instance.delete(_kServerUrlKey);
    }
  }

  Future<void> setUrl(String url) async {
    final clean = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    if (!_isValidUrl(clean)) return;
    state = clean;
    await AppStorage.instance.write(_kServerUrlKey, clean);
  }

  static bool _isValidUrl(String value) {
    try {
      final uri = Uri.parse(value);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> reset() async {
    state = kDefaultServerUrl;
    await AppStorage.instance.delete(_kServerUrlKey);
  }
}

final serverUrlProvider =
    NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);
