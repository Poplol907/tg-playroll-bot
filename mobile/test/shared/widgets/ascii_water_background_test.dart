import 'package:cosmo_studio/shared/widgets/ascii_water_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AsciiWaterBackground does not tick while idle', (tester) async {
    var ticks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AsciiWaterBackground(
          onDebugTick: () => ticks++,
          child: const Text('content'),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));

    expect(ticks, 0);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('AsciiWaterBackground starts ticking after touch',
      (tester) async {
    var ticks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AsciiWaterBackground(
          onDebugTick: () => ticks++,
          child: const Text('content'),
        ),
      ),
    );

    await tester.tap(find.text('content'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(ticks, greaterThan(0));
  });
}
