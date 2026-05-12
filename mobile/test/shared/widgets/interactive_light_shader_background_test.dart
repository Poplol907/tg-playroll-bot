import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/shared/widgets/interactive_light_shader_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('light shader splats begin on touch and decay to idle',
      (tester) async {
    final splatCounts = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 240,
          child: InteractiveLightShaderBackground(
            tokens: CosmoThemeTokens.lightShader,
            onDebugSplatCountChanged: splatCounts.add,
            child: const Text('content'),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(80, 80));
    await tester.pump();

    expect(splatCounts, contains(1));

    await tester.pump(const Duration(milliseconds: 1100));

    expect(splatCounts.last, 0);
  });

  testWidgets('light shader move splats reset after pointer up',
      (tester) async {
    final splatCounts = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 240,
          child: InteractiveLightShaderBackground(
            tokens: CosmoThemeTokens.lightShader,
            onDebugSplatCountChanged: splatCounts.add,
            child: const Text('content'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(40, 40));
    await tester.pump();
    await gesture.moveTo(const Offset(120, 120));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 1100));

    expect(splatCounts.any((count) => count >= 2), isTrue);
    expect(splatCounts.last, 0);
  });

  testWidgets('light shader throttles tiny pointer moves', (tester) async {
    final splatCounts = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 240,
          child: InteractiveLightShaderBackground(
            tokens: CosmoThemeTokens.lightShader,
            onDebugSplatCountChanged: splatCounts.add,
            child: const Text('content'),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(const Offset(40, 40));
    await tester.pump();

    for (var i = 1; i <= 12; i++) {
      await gesture.moveTo(Offset(40 + i.toDouble(), 40));
      await tester.pump(const Duration(milliseconds: 8));
    }

    await gesture.moveTo(const Offset(96, 40));
    await tester.pump();
    await gesture.up();

    expect(splatCounts, contains(1));
    expect(splatCounts, contains(2));
    expect(splatCounts.where((count) => count > 2), isEmpty);
  });

  testWidgets('reduced motion bypasses pointer splats', (tester) async {
    final splatCounts = <int>[];

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: SizedBox(
            width: 240,
            height: 240,
            child: InteractiveLightShaderBackground(
              tokens: CosmoThemeTokens.lightShader,
              onDebugSplatCountChanged: splatCounts.add,
              child: const Text('content'),
            ),
          ),
        ),
      ),
    );

    await tester.tapAt(const Offset(80, 80));
    await tester.pump();

    expect(splatCounts, isEmpty);
    expect(
      find.descendant(
        of: find.byType(InteractiveLightShaderBackground),
        matching: find.byType(Listener),
      ),
      findsNothing,
    );
    expect(find.text('content'), findsOneWidget);
  });
}
