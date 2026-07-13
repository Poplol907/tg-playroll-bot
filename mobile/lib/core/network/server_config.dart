import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/app_storage.dart';

const _kServerUrlKey = 'server_url';
// Production API over HTTPS (Caddy + Let's Encrypt). A-запись api.cosmo-studio.com → сервер.
const kDefaultServerUrl = 'https://api.cosmo-studio.com';

/// Validates which server endpoints are safe to use from the app.
///
/// HTTPS works in every build. Plain HTTP is deliberately limited to local
/// development endpoints while debugging, so release builds cannot send auth
/// tokens over an unencrypted connection.
class ServerUrlPolicy {
  static String? validate(String value, {bool isDebugMode = kDebugMode}) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.host.isEmpty) {
      return 'Введите корректный адрес сервера.';
    }
    if (uri.scheme == 'https') return null;
    if (uri.scheme != 'http') {
      return 'Используйте HTTPS-адрес сервера.';
    }
    if (isDebugMode && _isLocalDevelopmentHost(uri.host)) return null;
    return isDebugMode
        ? 'HTTP разрешён только для localhost или частной сети в debug-режиме.'
        : 'В релизной версии разрешены только HTTPS-адреса сервера.';
  }

  static bool _isLocalDevelopmentHost(String host) {
    final normalized = host.toLowerCase();
    if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
      return true;
    }
    if (normalized == '::1') return true;
    if (RegExp(r'^f[cd][0-9a-f]{2}:').hasMatch(normalized)) {
      return true; // IPv6 unique local address (fc00::/7).
    }
    if (RegExp(r'^fe[89ab][0-9a-f]:').hasMatch(normalized)) {
      return true; // IPv6 link-local (fe80::/10).
    }

    final octets = normalized.split('.');
    if (octets.length != 4) return false;
    final values = octets.map(int.tryParse).toList();
    if (values.any((value) => value == null || value < 0 || value > 255)) {
      return false;
    }
    final first = values[0]!;
    final second = values[1]!;
    return first == 127 ||
        first == 10 ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
}

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
    if (saved != null &&
        saved.isNotEmpty &&
        ServerUrlPolicy.validate(saved) == null) {
      state = saved;
    } else if (saved != null && saved.isNotEmpty) {
      // Corrupt/invalid value — clear it and fall back to default
      await AppStorage.instance.delete(_kServerUrlKey);
    }
  }

  Future<String?> setUrl(String url) async {
    final clean = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    final validationError = ServerUrlPolicy.validate(clean);
    if (validationError != null) return validationError;
    state = clean;
    await AppStorage.instance.write(_kServerUrlKey, clean);
    return null;
  }

  Future<void> reset() async {
    state = kDefaultServerUrl;
    await AppStorage.instance.delete(_kServerUrlKey);
  }
}

final serverUrlProvider =
    NotifierProvider<ServerUrlNotifier, String>(ServerUrlNotifier.new);
