import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/core/theme/nebula_alpha.dart';
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

  testWidgets('GlowMenuBar uses nav surface profile in light theme',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightLite,
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
            ],
          ),
        ),
      ),
    );

    final container = tester.widget<Container>(
      find.byKey(const ValueKey('glow-menu-bar-surface')),
    );
    final decoration = container.decoration! as BoxDecoration;
    final border = decoration.border! as Border;

    expect(
      decoration.color,
      CosmoThemeTokens.lightLite.denseSurface
          .withValues(alpha: NebulaAlpha.solid),
    );
    expect(border.top.color, CosmoThemeTokens.lightLite.surfaceBorder);
  });

  testWidgets('GlowMenuBar fits four tabs on narrow phones', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
              GlowMenuItem(
                icon: Icons.payments_outlined,
                label: 'Зарплата',
                glowColor: Colors.green,
              ),
              GlowMenuItem(
                icon: Icons.settings_outlined,
                label: 'Настройки',
                glowColor: Colors.amber,
              ),
            ],
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Календарь'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });

  testWidgets('GlowMenuBar dock magnification scales the focal tab',
      (tester) async {
    final magnify = ValueNotifier<double>(0);
    addTearDown(magnify.dispose);

    Widget bar() => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: GlowMenuBar(
              currentIndex: 0,
              onTap: (_) {},
              magnify: magnify,
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
        );

    await tester.pumpWidget(bar());
    // getRect accounts for ancestor Transform.scale (paint-time), so the
    // on-screen icon rect reflects the dock magnification.
    final tab1Rest = tester.getRect(find.byIcon(Icons.people_outline_rounded));

    // Slide the focal position fully onto tab 1 — it should grow.
    magnify.value = 1.0;
    await tester.pump();
    final tab1Focused =
        tester.getRect(find.byIcon(Icons.people_outline_rounded));

    expect(tab1Focused.width, greaterThan(tab1Rest.width));
  });

  testWidgets('GlowMenuBar owns horizontal section swipe gestures',
      (tester) async {
    var dragStarted = false;
    var dragDelta = 0.0;
    var dragEnded = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GlowMenuBar(
            currentIndex: 0,
            onTap: (_) {},
            onHorizontalDragStart: (_) => dragStarted = true,
            onHorizontalDragUpdate: (details) => dragDelta += details.delta.dx,
            onHorizontalDragEnd: (_) => dragEnded = true,
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

    final surface = find.byKey(const ValueKey('glow-menu-bar-surface'));
    await tester.drag(surface, const Offset(-120, 0));
    await tester.pump();

    expect(dragStarted, isTrue);
    expect(dragDelta, lessThan(0));
    expect(dragEnded, isTrue);
  });

  testWidgets(
      'GlowMenuBar admin layout centers Studio and keeps empty bar inert',
      (tester) async {
    final taps = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: GlowMenuBar(
            currentIndex: 0,
            onTap: taps.add,
            items: const [
              GlowMenuItem(
                icon: Icons.shield_outlined,
                label: 'Студия',
                glowColor: Colors.amber,
              ),
              GlowMenuItem(
                icon: Icons.settings_outlined,
                label: 'Настройки',
                glowColor: Colors.blueGrey,
              ),
            ],
          ),
        ),
      ),
    );

    final surfaceRect = tester.getRect(
      find.byKey(const ValueKey('glow-menu-bar-surface')),
    );
    final studioCenter = tester.getCenter(find.byIcon(Icons.shield_outlined));
    final settingsCenter =
        tester.getCenter(find.byIcon(Icons.settings_outlined));

    expect(
        studioCenter.dx, moreOrLessEquals(surfaceRect.center.dx, epsilon: 1));
    expect(settingsCenter.dx, greaterThan(surfaceRect.right - 64));

    await tester.tapAt(Offset(surfaceRect.left + 32, surfaceRect.center.dy));
    await tester.pump();
    expect(taps, isEmpty);

    await tester.tapAt(studioCenter);
    await tester.pump();
    expect(taps, [0]);

    await tester.tapAt(settingsCenter);
    await tester.pump();
    expect(taps, [0, 1]);
  });
}
