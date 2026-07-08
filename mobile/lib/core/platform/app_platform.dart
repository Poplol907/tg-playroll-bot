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

  /// Android-класс GPU не тянет вечные ambient-циклы (живые фоны, дыхание,
  /// shimmer): в покое они держат raster-поток занятым и режут весь app до
  /// ~20fps. Гейт ТОЛЬКО для ambient-движения — transition/tap-анимации
  /// остаются живыми. defaultTargetPlatform (а не Platform.isAndroid),
  /// чтобы переопределяться в тестах.
  static bool get liteGraphics =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
