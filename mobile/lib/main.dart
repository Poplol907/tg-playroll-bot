import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/platform/app_platform.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_visual_mode.dart';
import 'core/router/app_router.dart';
import 'shared/widgets/global_touch_overlay.dart';
import 'shared/widgets/theme_reveal_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Платформо-адаптивное хранилище (macOS = NSUserDefaults, iOS/Android = Keychain)
  await AppStorage.init();

  // Восстанавливаем выбранную пользователем тему (иначе при перезапуске
  // всегда вставала бы тёмная).
  final savedMode = visualModeFromStored(
      await AppStorage.instance.read(kVisualModeStorageKey));

  // Русская локаль для дат
  await initializeDateFormatting('ru', null);

  if (AppPlatform.isMobile) {
    // OLED: чёрный статус-бар (только мобайл)
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Portrait-only на мобайле; десктоп поддерживает любую ориентацию
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  runApp(
    ProviderScope(
      overrides: [
        appVisualModeProvider.overrideWith((ref) => savedMode),
      ],
      child: const CosmoApp(),
    ),
  );
}

class CosmoApp extends ConsumerWidget {
  const CosmoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final visualMode = ref.watch(appVisualModeProvider);

    return MaterialApp.router(
      title: 'Cosmo Studio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightThemeFor(visualMode),
      darkTheme: AppTheme.darkInternals,
      themeMode: AppTheme.themeModeFor(visualMode),
      routerConfig: router,
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        return ThemeRevealOverlay(
          child: GlobalTouchOverlay(child: child),
        );
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ru'),
        Locale('en'),
      ],
      locale: const Locale('ru'),
    );
  }
}
