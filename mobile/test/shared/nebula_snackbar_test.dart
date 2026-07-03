import 'package:cosmo_studio/shared/widgets/nebula_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host({required void Function(BuildContext) onTap}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => onTap(context),
              child: const Text('fire'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('toast is pinned near the top and auto-dismisses',
      (tester) async {
    await tester.pumpWidget(host(
      onTap: (context) => showNebulaSnackBar(
        context,
        title: 'Не удалось сохранить',
        message: 'Попробуйте снова',
        tone: NebulaSnackTone.error,
      ),
    ));

    await tester.tap(find.text('fire'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final toast = find.byKey(const ValueKey('nebula-toast'));
    expect(toast, findsOneWidget);
    expect(find.text('Не удалось сохранить'), findsOneWidget);
    // Top-anchored: the whole point is one fixed height on every screen.
    expect(tester.getTopLeft(toast).dy, lessThan(100));

    // Auto-dismiss after its duration + exit animation.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
    expect(toast, findsNothing);
  });

  testWidgets('a new toast replaces the previous one', (tester) async {
    var counter = 0;
    await tester.pumpWidget(host(
      onTap: (context) => showNebulaSnackBar(
        context,
        title: 'Тост ${++counter}',
      ),
    ));

    await tester.tap(find.text('fire'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Тост 1'), findsOneWidget);

    await tester.tap(find.text('fire'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Тост 1'), findsNothing);
    expect(find.text('Тост 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('nebula-toast')), findsOneWidget);

    // Drain the auto-close timer so the test ends clean.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('toast shows above a modal bottom sheet at the same height',
      (tester) async {
    await tester.pumpWidget(host(
      onTap: (context) {
        showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SizedBox(
            height: 200,
            child: Center(
              child: ElevatedButton(
                onPressed: () => showNebulaSnackBar(
                  sheetContext,
                  title: 'Ошибка в шите',
                  tone: NebulaSnackTone.error,
                ),
                child: const Text('sheet-fire'),
              ),
            ),
          ),
        );
      },
    ));

    await tester.tap(find.text('fire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sheet-fire'));
    await tester.pump(const Duration(milliseconds: 300));

    final toast = find.byKey(const ValueKey('nebula-toast'));
    expect(toast, findsOneWidget);
    // Same fixed top anchor even when fired from inside a sheet.
    expect(tester.getTopLeft(toast).dy, lessThan(100));

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
