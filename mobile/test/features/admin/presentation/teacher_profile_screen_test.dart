import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/data/payouts_repository.dart';
import 'package:cosmo_studio/features/admin/data/rates_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/screens/admin_screen.dart';
import 'package:cosmo_studio/shared/widgets/app_safe_layout.dart';
import 'package:cosmo_studio/shared/widgets/stellar_button.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeRatesRepository extends RatesRepository {
  _FakeRatesRepository() : super(Dio());

  @override
  Future<int> getDefaultRate(int teacherId) async => 60000;
}

class _FakePayoutsRepository extends PayoutsRepository {
  _FakePayoutsRepository() : super(Dio());

  @override
  Future<int> getPaidSum(int teacherId, String monthYear) async => 0;
}

void main() {
  const user = OrgUser(
    id: 7,
    login: 'anya',
    role: 'TEACHER',
    teacherName: 'Аня Петрова',
    hasPassword: true,
  );
  const stats = TeacherStats(
    teacherId: 7,
    teacherName: 'Аня Петрова',
    lessonsDone: 12,
    lessonsMissed: 2,
    lessonsCancelledMakeup: 1,
    lessonsDebt: 0,
    totalAmount: 48000,
  );

  Future<void> openProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ratesRepositoryProvider.overrideWithValue(_FakeRatesRepository()),
          payoutsRepositoryProvider.overrideWithValue(_FakePayoutsRepository()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TeacherProfileEntry.button(
                context: context,
                user: user,
                stats: stats,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-profile'));
    // NOT pumpAndSettle: the app background (AppBackgroundHost) runs an ambient
    // animation that never settles. Pump once to start the push, then advance
    // past the SpacePageRoute transition with a fixed duration.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> swipePager(WidgetTester tester) async {
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets(
      'tapping a teacher opens a full-screen profile (not a Dialog) with '
      'identity, one stats pager tile and StellarButton actions',
      (tester) async {
    await openProfile(tester);

    // It is a pushed screen, not a Dialog.
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Аня Петрова'), findsWidgets);

    // Scroll dissolves at the edges instead of hard-clipping.
    expect(
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.byType(Column),
      ),
      findsWidgets,
    );
    expect(find.byType(ScrollEdgeFade), findsWidgets);

    // All stats live in ONE swipeable tile now — no separate islands.
    expect(find.byKey(const ValueKey('teacher-stats-pager')), findsOneWidget);
    expect(find.byType(PageView), findsOneWidget);

    // Page 1: month stats.
    expect(find.text('СТАТИСТИКА МЕСЯЦА'), findsOneWidget);
    expect(find.text('Проведено'), findsOneWidget);
    expect(find.text('12'), findsWidgets);

    // Bottom actions are StellarButtons with the preserved wiring.
    expect(
        find.widgetWithText(StellarButton, 'Открыть как педагог'),
        findsOneWidget);
    expect(
        find.widgetWithText(StellarButton, 'Сменить пароль'), findsOneWidget);
    expect(find.widgetWithText(StellarButton, 'Отключить'), findsOneWidget);
    expect(find.widgetWithText(StellarButton, 'Удалить навсегда'),
        findsOneWidget);
  });

  testWidgets(
      'stats pager swipes месяц → выплаты → ставка and dots jump back',
      (tester) async {
    await openProfile(tester);

    // Swipe → page 2: payouts.
    await swipePager(tester);
    expect(find.text('К выплате'), findsOneWidget);
    expect(find.textContaining('48'), findsWidgets); // 48 000 owed
    expect(find.text('Отметить выплату'), findsOneWidget);

    // Swipe → page 3: rate.
    await swipePager(tester);
    expect(find.text('СТАВКА ЗА УРОК'), findsOneWidget);
    expect(find.textContaining('60'), findsWidgets); // 60 000 per lesson
    expect(find.text('Изменить'), findsOneWidget);

    // Tapping the first dot returns to the month page.
    await tester.tap(find.byKey(const ValueKey('stats-pager-dot-0')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('СТАТИСТИКА МЕСЯЦА'), findsOneWidget);
  });
}
