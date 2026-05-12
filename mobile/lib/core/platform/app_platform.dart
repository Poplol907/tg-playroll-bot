import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

/// Утилита определения платформы.
/// Используется для адаптации UI под мобайл и десктоп.
abstract class AppPlatform {
  @visibleForTesting
  static bool? debugOverrideIsDesktop;

  static bool get isDesktop =>
      debugOverrideIsDesktop ??
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  static bool get isMobile => debugOverrideIsDesktop != null
      ? !debugOverrideIsDesktop!
      : !kIsWeb && (Platform.isIOS || Platform.isAndroid);
}
