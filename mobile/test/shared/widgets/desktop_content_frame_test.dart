import 'package:cosmo_studio/core/platform/app_platform.dart';
import 'package:cosmo_studio/core/router/app_router.dart';
import 'package:cosmo_studio/core/services/update_service.dart';
import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:cosmo_studio/shared/widgets/desktop_content_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    await initializeDateFormatting('ru');
  });

  tearDown(() {
    AppPlatform.debugOverrideIsDesktop = null;
  });

  testWidgets('DesktopContentFrame constrains wide desktop content',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DesktopContentFrame(
            header: SizedBox(key: Key('header'), height: 48),
            child: SizedBox(key: Key('body')),
          ),
        ),
      ),
    );

    final headerWidth = tester.getSize(find.byKey(const Key('header'))).width;
    final bodyWidth = tester.getSize(find.byKey(const Key('body'))).width;

    expect(headerWidth, lessThan(1800));
    expect(headerWidth, lessThanOrEqualTo(1280));
    expect(bodyWidth, headerWidth);
  });

  testWidgets('AppShell wraps desktop month bar and child in content frame',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = true;
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateInfoProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(
          home: AppShell(
            currentIndex: 0,
            child: ColoredBox(
              key: Key('route-child'),
              color: Colors.transparent,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(DesktopContentFrame), findsOneWidget);
    expect(find.byKey(const Key('route-child')), findsOneWidget);
  });
}
