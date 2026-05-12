import 'package:cosmo_studio/core/platform/app_platform.dart';
import 'package:cosmo_studio/core/router/app_router.dart';
import 'package:cosmo_studio/core/services/update_service.dart';
import 'package:cosmo_studio/shared/providers/month_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
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
  });
}
