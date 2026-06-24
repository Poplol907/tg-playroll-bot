import 'package:cosmo_studio/core/platform/app_platform.dart';
import 'package:cosmo_studio/core/router/app_router.dart';
import 'package:cosmo_studio/core/services/update_service.dart';
import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/nebula_radii.dart';
import 'package:cosmo_studio/core/theme/nebula_tokens.dart';
import 'package:cosmo_studio/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmo_studio/shared/providers/month_provider.dart';
import 'package:cosmo_studio/shared/models/user.dart';
import 'package:cosmo_studio/shared/widgets/app_chrome_metrics.dart';
import 'package:cosmo_studio/shared/widgets/app_safe_layout.dart';
import 'package:cosmo_studio/shared/widgets/nebula_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Finder mobileTopIsland() => find.byKey(const ValueKey('mobile-top-island'));
  Finder monthPill() => find.byKey(const ValueKey('month-pill'));
  Finder previousMonthArrow() =>
      find.byKey(const ValueKey('previous-month-arrow'));
  Finder nextMonthArrow() => find.byKey(const ValueKey('next-month-arrow'));

  Widget shellForMonth(
    DateTime month, {
    Widget child = const Text('content'),
    ThemeData? theme,
  }) {
    return ProviderScope(
      key: ValueKey(month),
      overrides: [
        updateInfoProvider.overrideWith((ref) async => null),
        globalMonthProvider.overrideWith((ref) => month),
      ],
      child: MaterialApp(
        theme: theme,
        home: AppShell(currentIndex: 0, child: child),
      ),
    );
  }

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
    // Dragging the nav-pill RIGHT now moves the pager to the NEXT page
    // (direct mapping: finger right → page index up). The previous inverted
    // behaviour was a bug — pill should follow the finger, not chase it.
    await navGesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await navGesture.moveBy(const Offset(96, 0));
    await tester.pump();
    expect(controller.page, greaterThan(0));
    await navGesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'mobile month island keeps identical fixed geometry in every month state',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = false;
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);
    final otherMonth = DateTime(now.year, now.month - 1);

    await tester.pumpWidget(shellForMonth(currentMonth));
    await tester.pump();
    final currentHeight = tester.getSize(mobileTopIsland()).height;

    await tester.pumpWidget(shellForMonth(otherMonth));
    await tester.pump();
    final otherHeight = tester.getSize(mobileTopIsland()).height;

    expect(currentHeight, AppChromeMetrics.mobileTopIslandExtent);
    expect(otherHeight, currentHeight);
    expect(find.text('нажмите для возврата'), findsNothing);

    final left = find.ancestor(
      of: find.byIcon(Icons.chevron_left_rounded),
      matching: find.byType(NebulaSurface),
    );
    final right = find.ancestor(
      of: find.byIcon(Icons.chevron_right_rounded),
      matching: find.byType(NebulaSurface),
    );
    expect(tester.getSize(left), const Size.square(38));
    expect(tester.getSize(right), const Size.square(38));
  });

  testWidgets('mobile top reservation equals rendered island extent',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = false;
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);

    await tester.pumpWidget(shellForMonth(month));
    await tester.pump();

    expect(
      AppChromeMetrics.routeContentTopReservation,
      tester.getSize(mobileTopIsland()).height,
    );
  });

  for (final theme in [AppTheme.darkInternals, AppTheme.lightLite]) {
    testWidgets(
        'top month and bottom navigation pills use semantic geometry in '
        '${theme.brightness.name}', (tester) async {
      AppPlatform.debugOverrideIsDesktop = false;
      await tester.pumpWidget(
        shellForMonth(DateTime(2026, 6), theme: theme),
      );
      await tester.pump();

      final topPill = tester.widget<NebulaSurface>(monthPill());
      final navContainer = tester.widget<Container>(
        find.byKey(const ValueKey('glow-menu-bar-surface')),
      );
      final navDecoration = navContainer.decoration! as BoxDecoration;

      expect(topPill.radiusRole, NebulaRadiusRole.pill);
      expect(navDecoration.borderRadius, NebulaRadii.pillBorder);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('long month label fits fixed chrome at 320px', (tester) async {
    AppPlatform.debugOverrideIsDesktop = false;
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final month = DateTime(2026, 9);

    await tester.pumpWidget(shellForMonth(month));
    await tester.pump();

    expect(
      find.text(DateFormat('MMMM yyyy', 'ru').format(month)),
      findsOneWidget,
    );
    expect(
      tester.getSize(mobileTopIsland()).height,
      AppChromeMetrics.mobileTopIslandExtent,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in const [
    Size(320, 720),
    Size(390, 844),
    Size(430, 932),
  ]) {
    for (final isCurrentMonth in const [true, false]) {
      testWidgets(
          'top island geometry is stable at $size '
          '(${isCurrentMonth ? 'current' : 'other'} month)', (tester) async {
        AppPlatform.debugOverrideIsDesktop = false;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final now = DateTime.now();
        final month = isCurrentMonth
            ? DateTime(now.year, now.month)
            : DateTime(now.year, now.month - 1);

        await tester.pumpWidget(
          shellForMonth(
            month,
            child: Builder(
              builder: (context) => Padding(
                padding: AppSafeInsets.screen(context),
                child: const SizedBox(
                  key: ValueKey('first-route-content'),
                  height: 40,
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final island = tester.getRect(mobileTopIsland());
        final pill = tester.getRect(monthPill());
        final previous = tester.getRect(previousMonthArrow());
        final next = tester.getRect(nextMonthArrow());
        final content = tester.getRect(
          find.byKey(const ValueKey('first-route-content')),
        );

        expect(island.height, AppChromeMetrics.mobileTopIslandExtent);
        expect(previous.size, next.size);
        expect(previous.size, const Size.square(38));
        expect(previous.right, lessThanOrEqualTo(pill.left));
        expect(pill.right, lessThanOrEqualTo(next.left));
        expect(content.top - island.bottom, NebulaTokens.sp20);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in const [1024.0, 1440.0]) {
    testWidgets('desktop month header has no overflow at ${width}px',
        (tester) async {
      AppPlatform.debugOverrideIsDesktop = true;
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(shellForMonth(DateTime(2026, 9)));
      await tester.pump();

      expect(
        find.text(DateFormat('MMMM yyyy', 'ru').format(DateTime(2026, 9))),
        findsOneWidget,
      );
      final pill = find.ancestor(
        of: find.text(
          DateFormat('MMMM yyyy', 'ru').format(DateTime(2026, 9)),
        ),
        matching: find.byType(NebulaSurface),
      );
      final pillWidth = tester.getSize(pill).width;
      expect(pillWidth, isNot(AppChromeMetrics.monthPillMaxWidth));
      expect(pillWidth, lessThan(300));
      expect(tester.takeException(), isNull);
    });
  }
}
