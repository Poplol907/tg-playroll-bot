import 'package:cosmo_studio/shared/widgets/nebula_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NebulaSegmentedControl shows segments and reports taps',
      (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => NebulaSegmentedControl(
              segments: const ['Педагоги', 'Ученики'],
              selectedIndex: selected,
              onChanged: (i) => setState(() => selected = i),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Педагоги'), findsOneWidget);
    expect(find.text('Ученики'), findsOneWidget);

    await tester.tap(find.text('Ученики'));
    await tester.pump();
    expect(selected, 1);
  });
}
