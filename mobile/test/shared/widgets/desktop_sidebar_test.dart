import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/core/theme/nebula_alpha.dart';
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

  testWidgets('DesktopSidebar uses nav surface profile in light theme',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightLite,
        home: Scaffold(
          body: DesktopSidebar(
            currentIndex: 0,
            onTap: (_) {},
            items: const [
              DesktopSidebarItem(
                icon: Icons.calendar_month_rounded,
                label: 'Календарь',
              ),
            ],
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('desktop-sidebar-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(
      decoration.color,
      CosmoThemeTokens.lightLite.denseSurface
          .withValues(alpha: NebulaAlpha.solid),
    );
    expect(border.right.color, CosmoThemeTokens.lightLite.surfaceBorder);
  });
}
