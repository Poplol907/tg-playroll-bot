import 'package:cosmo_studio/core/theme/app_visual_mode.dart';
import 'package:cosmo_studio/core/theme/nebula_tokens.dart';
import 'package:cosmo_studio/shared/widgets/theme_reveal_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dark to light reveals edges before the center', () {
    final center = ThemeRevealGeometry.oldFrameOpacity(
      direction: ThemeRevealDirection.edgesToCenter,
      progress: 0.5,
      normalizedRadius: 0,
    );
    final edge = ThemeRevealGeometry.oldFrameOpacity(
      direction: ThemeRevealDirection.edgesToCenter,
      progress: 0.5,
      normalizedRadius: 1,
    );

    expect(center, greaterThan(edge));
  });

  test('light to dark reveals center before the edges', () {
    final center = ThemeRevealGeometry.oldFrameOpacity(
      direction: ThemeRevealDirection.centerToEdges,
      progress: 0.5,
      normalizedRadius: 0,
    );
    final edge = ThemeRevealGeometry.oldFrameOpacity(
      direction: ThemeRevealDirection.centerToEdges,
      progress: 0.5,
      normalizedRadius: 1,
    );

    expect(center, lessThan(edge));
  });

  testWidgets('global overlay switches the visual mode and completes cleanly',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ThemeRevealOverlay(
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () => ThemeRevealOverlay.switchMode(
                  context,
                  AppVisualMode.lightLite,
                ),
                child: const Text('switch'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('switch'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(container.read(appVisualModeProvider), AppVisualMode.lightLite);

    await tester.pump(NebulaTokens.screenTransition);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
