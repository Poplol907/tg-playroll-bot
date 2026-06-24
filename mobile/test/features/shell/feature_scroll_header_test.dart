import 'package:cosmo_studio/core/network/api_client.dart';
import 'package:cosmo_studio/core/platform/app_platform.dart';
import 'package:cosmo_studio/core/router/app_router.dart';
import 'package:cosmo_studio/core/services/update_service.dart';
import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmo_studio/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:cosmo_studio/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:cosmo_studio/features/students/data/students_repository.dart';
import 'package:cosmo_studio/features/students/presentation/screens/students_screen.dart';
import 'package:cosmo_studio/shared/models/student.dart';
import 'package:cosmo_studio/shared/models/user.dart';
import 'package:cosmo_studio/shared/providers/month_provider.dart';
import 'package:cosmo_studio/shared/widgets/app_screen_header.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const teacher = UserModel(
    id: 7,
    orgId: 1,
    login: 'teacher',
    role: 'TEACHER',
    teacherName: 'Анна Смирнова',
  );
  final month = DateTime(2026, 6);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init();
    await initializeDateFormatting('ru');
  });

  setUp(() {
    AppPlatform.debugOverrideIsDesktop = false;
  });

  tearDown(() {
    AppPlatform.debugOverrideIsDesktop = null;
  });

  Dio offlineDio(ValueNotifier<int> requests) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.value++;
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              message: 'Widget tests must stay offline',
            ),
          );
        },
      ),
    );
    return dio;
  }

  MaterialApp testApp(Widget home) => MaterialApp(
        theme: AppTheme.darkInternals,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: home,
      );

  testWidgets('actual Calendar header scrolls below shell chrome and away',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = ValueNotifier<int>(0);
    addTearDown(requests.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(offlineDio(requests)),
          updateInfoProvider.overrideWith((ref) async => null),
          currentUserProvider.overrideWithValue(teacher),
          globalMonthProvider.overrideWith((ref) => month),
          lessonsProvider.overrideWith((ref, monthYear) async => const []),
        ],
        child: testApp(
          const AppShell(
            currentIndex: 0,
            child: CalendarScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final header = find.byType(AppScreenHeader);
    final scroll = find.byKey(const ValueKey('app-custom-scroll-view'));
    final monthPill = find.byKey(const ValueKey('month-pill'));
    expect(header, findsOneWidget);
    expect(tester.getRect(monthPill).bottom,
        lessThanOrEqualTo(tester.getRect(header).top));
    final initialHeaderY = tester.getTopLeft(header).dy;

    await tester.drag(scroll, const Offset(0, -96));
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.getTopLeft(header).dy, lessThan(initialHeaderY));

    await tester.drag(scroll, const Offset(0, -320));
    await tester.pump(const Duration(milliseconds: 32));
    expect(header, findsNothing);
    expect(find.text(teacher.displayName), findsNothing);
    expect(requests.value, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('actual lazy Students list shares one scroll-away header',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final requests = ValueNotifier<int>(0);
    addTearDown(requests.dispose);
    final students = List.generate(
      30,
      (index) => StudentModel(
        id: index + 1,
        orgId: 1,
        firstName: 'Ученик',
        lastName: '$index',
        status: 'ACTIVE',
        createdAt: DateTime(2025),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(offlineDio(requests)),
          updateInfoProvider.overrideWith((ref) async => null),
          currentUserProvider.overrideWithValue(teacher),
          globalMonthProvider.overrideWith((ref) => month),
          studentsProvider.overrideWith((ref) async => students),
        ],
        child: testApp(
          const AppShell(
            currentIndex: 1,
            child: StudentsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    final header = find.byType(AppScreenHeader);
    final firstStudent = find.text('Ученик 0');
    final scroll = find.byKey(const ValueKey('app-custom-scroll-view'));
    expect(header, findsOneWidget);
    expect(
      find.descendant(of: header, matching: find.text('Ученики')),
      findsOneWidget,
    );
    final initialHeaderY = tester.getTopLeft(header).dy;
    final initialStudentY = tester.getTopLeft(firstStudent).dy;

    await tester.drag(scroll, const Offset(0, -80));
    await tester.pump(const Duration(milliseconds: 32));
    expect(tester.getTopLeft(header).dy, lessThan(initialHeaderY));
    expect(tester.getTopLeft(firstStudent).dy, lessThan(initialStudentY));

    await tester.drag(scroll, const Offset(0, -280));
    await tester.pump(const Duration(milliseconds: 32));
    expect(header, findsNothing);
    expect(requests.value, 0);
    expect(tester.takeException(), isNull);
  });
}
