import 'package:cosmo_studio/features/admin/presentation/screens/search_screen.dart';
import 'package:cosmo_studio/shared/widgets/nebula_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('SearchScreen shows the Педагоги/Ученики segmented control',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();

    expect(find.byType(NebulaSegmentedControl), findsOneWidget);
    expect(find.text('Педагоги'), findsWidgets);
    expect(find.text('Ученики'), findsWidgets);
  });
}
