import 'package:cosmo_studio/shared/widgets/glow_menu_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GlowMenuBar avoids backdrop blur in the navigation chrome',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GlowMenuBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              GlowMenuItem(
                icon: Icons.calendar_month_rounded,
                label: 'Календарь',
                glowColor: Colors.blue,
              ),
              GlowMenuItem(
                icon: Icons.people_outline_rounded,
                label: 'Ученики',
                glowColor: Colors.purple,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Календарь'), findsOneWidget);
  });

  testWidgets('GlowMenuBar avoids perspective flip transforms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GlowMenuBar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              GlowMenuItem(
                icon: Icons.calendar_month_rounded,
                label: 'Календарь',
                glowColor: Colors.blue,
              ),
              GlowMenuItem(
                icon: Icons.people_outline_rounded,
                label: 'Ученики',
                glowColor: Colors.purple,
              ),
            ],
          ),
        ),
      ),
    );

    final perspectiveTransforms = tester
        .widgetList<Transform>(find.byType(Transform))
        .where((widget) => widget.transform.storage[7] != 0);

    expect(perspectiveTransforms, isEmpty);
  });
}
