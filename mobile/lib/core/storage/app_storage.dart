import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform-adaptive storage.
///
/// macOS   → SharedPreferences (NSUserDefaults) — no Keychain prompt, no password dialog.
/// iOS/Android → FlutterSecureStorage (encrypted Keychain / Android Keystore).
///
/// Call [AppStorage.init] once in main() before runApp().
class AppStorage {
  static AppStorage? _instance;

  // ignore: prefer_constructors_over_static_methods
  static AppStorage get instance {
    assert(_instance != null, 'AppStorage.init() has not been called yet');
    return _instance!;
  }

  final FlutterSecureStorage? _secure;
  final SharedPreferences? _prefs;

  AppStorage._({FlutterSecureStorage? secure, SharedPreferences? prefs})
      : _secure = secure,
        _prefs = prefs;

  /// Initialise the singleton. Must be awaited before any [read]/[write]/[delete] call.
  static Future<void> init() async {
    if (!kIsWeb && Platform.isMacOS) {
      // NSUserDefaults — no Keychain access dialog, works without code-signing.
      final prefs = await SharedPreferences.getInstance();
      _instance = AppStorage._(prefs: prefs);
    } else {
      // Encrypted Keychain (iOS) / EncryptedSharedPreferences (Android).
      const secure = FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
          // Keystore/encrypted-prefs corruption on Android throws on read;
          // main() reads storage before runApp(), so without self-reset the
          // app crash-loops at startup. Reset = forced re-login, not a brick.
          resetOnError: true,
        ),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );
      _instance = AppStorage._(secure: secure);
    }
  }

  Future<String?> read(String key) async {
    if (_prefs != null) return _prefs.getString(key);
    return _secure?.read(key: key);
  }

  Future<void> write(String key, String value) async {
    if (_prefs != null) {
      await _prefs.setString(key, value);
    } else {
      await _secure?.write(key: key, value: value);
    }
  }

  Future<void> delete(String key) async {
    if (_prefs != null) {
      await _prefs.remove(key);
    } else {
      await _secure?.delete(key: key);
    }
  }
}
