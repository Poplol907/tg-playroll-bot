import 'package:cosmo_studio/shared/widgets/desktop_sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DesktopSidebar avoids backdrop blur in the navigation chrome',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DesktopSidebar(
            currentIndex: 0,
            onTap: (_) {},
            onSettingsTap: () {},
            items: const [
              DesktopSidebarItem(
                icon: Icons.calendar_month_rounded,
                label: 'Календарь',
              ),
              DesktopSidebarItem(
                icon: Icons.people_outline_rounded,
                label: 'Ученики',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byIcon(Icons.calendar_month_rounded), findsOneWidget);
  });
}
