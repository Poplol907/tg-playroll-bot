import 'package:cosmo_studio/shared/widgets/sheet_error_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('collapsed when error is null, expands with the message',
      (tester) async {
    Future<void> pumpWith(String? error) => tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(children: [SheetErrorBanner(error: error)]),
            ),
          ),
        );

    await pumpWith(null);
    expect(find.byKey(const ValueKey('sheet-error-banner')), findsNothing);

    await pumpWith('Выберите педагога');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('sheet-error-banner')), findsOneWidget);
    expect(find.text('Выберите педагога'), findsOneWidget);

    await pumpWith(null);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('sheet-error-banner')), findsNothing);
  });
}
