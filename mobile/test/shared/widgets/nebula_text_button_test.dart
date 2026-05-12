import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/shared/widgets/nebula_text_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NebulaTextButton calls the enabled action', (tester) async {
    var tapped = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkInternals,
        home: Scaffold(
          body: Center(
            child: NebulaTextButton(
              label: 'Повторить',
              icon: Icons.refresh_rounded,
              onPressed: () => tapped++,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Повторить'));

    expect(tapped, 1);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('NebulaTextButton ignores taps while disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkInternals,
        home: const Scaffold(
          body: Center(
            child: NebulaTextButton(label: 'Недоступно'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Недоступно'));

    expect(tester.takeException(), isNull);
  });
}
