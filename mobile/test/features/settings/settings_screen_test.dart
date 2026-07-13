import 'package:cosmo_studio/core/storage/app_storage.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/settings/presentation/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(AppStorage.init);

  testWidgets('rejecting an HTTP server URL does not show saved feedback',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.darkInternals,
          home: const SettingsScreen(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'http://example.test');
    await tester.tap(find.text('Сохранить'));
    await tester.pump();

    expect(find.text('Сохранено'), findsNothing);
    expect(
      find.text(
          'HTTP разрешён только для localhost или частной сети в debug-режиме.'),
      findsOneWidget,
    );
  });
}
