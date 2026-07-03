import 'package:cosmo_studio/core/platform/app_platform.dart';
import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/core/theme/nebula_alpha.dart';
import 'package:cosmo_studio/features/auth/presentation/screens/login_screen.dart';
import 'package:cosmo_studio/features/auth/presentation/widgets/cosmo_login_sphere.dart';
import 'package:cosmo_studio/features/students/presentation/widgets/schedule_builder_modal.dart';
import 'package:cosmo_studio/shared/models/student.dart';
import 'package:cosmo_studio/shared/widgets/adaptive_modal.dart';
import 'package:cosmo_studio/shared/widgets/mist_modal.dart';
import 'package:cosmo_studio/shared/widgets/nebula_dialog.dart';
import 'package:cosmo_studio/shared/widgets/server_settings_modal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  testWidgets('schedule builder opens as dialog on desktop', (tester) async {
    AppPlatform.debugOverrideIsDesktop = true;
    final student = StudentModel(
      id: 1,
      orgId: 1,
      firstName: 'Али',
      lastName: 'Абидов',
      status: 'ACTIVE',
      createdAt: DateTime(2026),
      studentTeacherId: 10,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => ScheduleBuilderModal.show(
                  context,
                  student: student,
                  studentTeacherId: 10,
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('Вс'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('adaptive desktop modal avoids backdrop blur', (tester) async {
    AppPlatform.debugOverrideIsDesktop = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => AdaptiveModal.show<void>(
                context,
                builder: (_) => const Text('modal content'),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('modal content'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('adaptive desktop modal uses modal profile in light theme',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightLite,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => AdaptiveModal.show<void>(
                context,
                builder: (_) => const Text('modal content'),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('adaptive-modal-desktop-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(
      decoration.color,
      CosmoThemeTokens.lightLite.denseSurface.withValues(
        alpha: NebulaAlpha.occludingSurface,
      ),
    );
    expect(
      (decoration.border! as Border).top.color,
      CosmoThemeTokens.lightLite.surfaceBorder,
    );
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets(
      'adaptive desktop modal uses occluding card material in dark theme',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkInternals,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => AdaptiveModal.show<void>(
                context,
                builder: (_) => const Text('modal content'),
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('adaptive-modal-desktop-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;

    expect(decoration.color, isNot(CosmoThemeTokens.darkInternals.surface));
    expect(decoration.color!.a, NebulaAlpha.occludingSurface);
    expect(decoration.gradient, isNull);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('mist modal surface avoids backdrop blur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MistModal(
            child: Text('sheet content'),
          ),
        ),
      ),
    );

    expect(find.text('sheet content'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('server settings modal is blur-free by default', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ServerSettingsModal(),
          ),
        ),
      ),
    );

    expect(find.text('Адрес сервера'), findsOneWidget);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('server settings modal uses modal profile in light theme',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightLite,
          home: const Scaffold(
            body: ServerSettingsModal(),
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('server-settings-modal-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(
      decoration.color,
      CosmoThemeTokens.lightLite.denseSurface.withValues(
        alpha: NebulaAlpha.occludingSurface,
      ),
    );
    expect(border.top.color, CosmoThemeTokens.lightLite.surfaceBorder);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('schedule builder opens as bottom sheet on mobile',
      (tester) async {
    AppPlatform.debugOverrideIsDesktop = false;
    final student = StudentModel(
      id: 1,
      orgId: 1,
      firstName: 'Али',
      lastName: 'Абидов',
      status: 'ACTIVE',
      createdAt: DateTime(2026),
      studentTeacherId: 10,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => ScheduleBuilderModal.show(
                  context,
                  student: student,
                  studentTeacherId: 10,
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('Вс'), findsOneWidget);
    // The ONLY blur belongs to the frosted route barrier; the sheet surface
    // itself stays blur-free (cheap matte material).
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      find.byKey(const ValueKey('frosted-sheet-barrier')),
      findsOneWidget,
    );
  });

  testWidgets('nebula confirm dialog returns selected action', (tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                result = await NebulaDialog.confirm(
                  context,
                  title: 'Удалить урок?',
                  message: 'Это действие нельзя отменить.',
                  confirmLabel: 'Удалить',
                  destructive: true,
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Удалить урок?'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('login screen uses the shared Cosmo login sphere',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.byType(CosmoLoginSphere), findsOneWidget);
    expect(
      tester
          .widget<CosmoLoginSphere>(find.byType(CosmoLoginSphere))
          .enableAmbientMotion,
      isTrue,
    );
  });
}
