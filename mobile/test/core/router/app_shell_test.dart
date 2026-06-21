import 'package:cosmo_studio/core/platform/app_platform.dart';
import 'package:cosmo_studio/core/router/app_router.dart';
import 'package:cosmo_studio/core/services/update_service.dart';
import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:cosmo_studio/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmo_studio/shared/providers/month_provider.dart';
import 'package:cosmo_studio/shared/models/user.dart';
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

  testWidgets('AppShell avoids backdrop blur in mobile shell chrome',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateInfoProvider.overrideWith((ref) async => null),
          globalMonthProvider.overrideWith((ref) => DateTime(2026, 5)),
        ],
        child: const MaterialApp(
          home: AppShell(
            currentIndex: 0,
            child: Text('content'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.textContaining('2026'), findsOneWidget);

    final pager = tester.widget<PageView>(find.byType(PageView));
    expect(pager.physics, isA<NeverScrollableScrollPhysics>());
  });

  testWidgets(
      'AppShell syncs distant tab routes without scrolling intermediate pages',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = false;

    Widget shell(int currentIndex) => ProviderScope(
          overrides: [
            updateInfoProvider.overrideWith((ref) async => null),
            globalMonthProvider.overrideWith((ref) => DateTime(2026, 5)),
          ],
          child: MaterialApp(
            home: AppShell(
              currentIndex: currentIndex,
              child: Text('content-$currentIndex'),
            ),
          ),
        );

    await tester.pumpWidget(shell(3));
    await tester.pump();

    final initialPager = tester.widget<PageView>(find.byType(PageView));
    expect(initialPager.controller!.page, 3);

    await tester.pumpWidget(shell(0));
    await tester.pump();

    final syncedPager = tester.widget<PageView>(find.byType(PageView));
    expect(syncedPager.controller!.page, 0);
    expect(syncedPager.controller!.position.isScrollingNotifier.value, isFalse);
  });

  testWidgets('only the mobile nav bar can drag the section pager',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          updateInfoProvider.overrideWith((ref) async => null),
          globalMonthProvider.overrideWith((ref) => DateTime(2026, 5)),
          currentUserProvider.overrideWithValue(
            const UserModel(
              id: 1,
              orgId: 1,
              login: 'admin',
              role: 'ADMIN',
            ),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(
            currentIndex: 0,
            child: Text('content'),
          ),
        ),
      ),
    );
    await tester.pump();

    final pager = tester.widget<PageView>(find.byType(PageView));
    final controller = pager.controller!;
    final pageRect = tester.getRect(find.byType(PageView));

    final contentGesture = await tester.startGesture(pageRect.center);
    await contentGesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(controller.page, 0);
    await contentGesture.up();

    final navSurface = find.byKey(const ValueKey('glow-menu-bar-surface'));
    final navGesture = await tester.startGesture(tester.getCenter(navSurface));
    await navGesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    await navGesture.moveBy(const Offset(-96, 0));
    await tester.pump();
    expect(controller.page, greaterThan(0));
    await navGesture.up();
    await tester.pumpAndSettle();
  });
}
