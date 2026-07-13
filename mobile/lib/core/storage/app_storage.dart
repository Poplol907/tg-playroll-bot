import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keychain/keystore-backed storage for app data, including auth tokens.
///
/// macOS uses Keychain through [FlutterSecureStorage]; it never falls back to
/// plaintext SharedPreferences.
///
/// Call [AppStorage.init] once in main() before runApp().
class AppStorage {
  static AppStorage? _instance;

  // ignore: prefer_constructors_over_static_methods
  static AppStorage get instance {
    assert(_instance != null, 'AppStorage.init() has not been called yet');
    return _instance!;
  }

  final FlutterSecureStorage _secure;

  AppStorage._({required FlutterSecureStorage secure}) : _secure = secure;

  /// Initialise the singleton. Must be awaited before any [read]/[write]/[delete] call.
  static Future<void> init({bool Function()? isMacOS}) async {
    final runsOnMacOS = isMacOS?.call() ?? (!kIsWeb && Platform.isMacOS);
    _instance = createForPlatform(isMacOS: runsOnMacOS);
  }

  /// Kept injectable to verify macOS never regresses to plaintext storage.
  @visibleForTesting
  static AppStorage createForPlatform({required bool isMacOS}) {
    return AppStorage._(secure: isMacOS ? _macOsSecureStorage : _secureStorage);
  }

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      // Keystore/encrypted-prefs corruption on Android throws on read;
      // main() reads storage before runApp(), so without self-reset the
      // app crash-loops at startup. Reset = forced re-login, not a brick.
      resetOnError: true,
    ),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _macOsSecureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @visibleForTesting
  bool get usesSecureStorage => true;

  @visibleForTesting
  bool get usesSharedPreferences => false;

  Future<String?> read(String key) async {
    return _secure.read(key: key);
  }

  Future<void> write(String key, String value) async {
    await _secure.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    await _secure.delete(key: key);
  }
}
