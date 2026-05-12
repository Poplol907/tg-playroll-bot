import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/features/auth/presentation/widgets/cosmo_login_sphere.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CosmoLoginSphere renders a themed symbol sphere',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CosmoLoginSphere(
            tokens: CosmoThemeTokens.darkInternals,
          ),
        ),
      ),
    );

    expect(find.byType(CosmoLoginSphere), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(CosmoLoginSphere),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('CosmoLoginSphere supports a static reduced-motion state',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(
            child: CosmoLoginSphere(
              tokens: CosmoThemeTokens.lightShader,
            ),
          ),
        ),
      ),
    );

    final sphere = tester.widget<CosmoLoginSphere>(
      find.byType(CosmoLoginSphere),
    );

    expect(sphere.tokens, CosmoThemeTokens.lightShader);
    expect(
      find.descendant(
        of: find.byType(CosmoLoginSphere),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
  });

  testWidgets('CosmoLoginSphere keeps ambient motion off by default',
      (tester) async {
    var ticks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CosmoLoginSphere(
            tokens: CosmoThemeTokens.darkInternals,
            onDebugAnimationTick: () => ticks++,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));

    expect(ticks, 0);
  });

  testWidgets('CosmoLoginSphere can opt into ambient motion', (tester) async {
    var ticks = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: CosmoLoginSphere(
            tokens: CosmoThemeTokens.darkInternals,
            enableAmbientMotion: true,
            onDebugAnimationTick: () => ticks++,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 120));

    expect(ticks, greaterThan(0));
  });
}
