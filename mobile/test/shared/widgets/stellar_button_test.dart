import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/nebula_colors.dart';
import 'package:cosmo_studio/shared/widgets/stellar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StellarButton removes dense text glow in light modes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightShader,
        home: Scaffold(
          body: StellarButton(
            label: 'Сохранить',
            icon: Icons.check_rounded,
            onPressed: () {},
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('Сохранить'));
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));

    expect(text.style?.shadows, isNull);
    expect(icon.shadows, isNull);
  });

  testWidgets('StellarButton keeps dark glow expressive but bounded',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkInternals,
        home: Scaffold(
          body: Center(
            child: StellarButton(
              label: 'Сохранить',
              icon: Icons.check_rounded,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(StellarButton)),
    );
    await tester.pump(const Duration(milliseconds: 140));

    final text = tester.widget<Text>(find.text('Сохранить'));
    final icon = tester.widget<Icon>(find.byIcon(Icons.check_rounded));
    final textShadows = text.style?.shadows;
    final iconShadows = icon.shadows;

    expect(textShadows, isNotNull);
    expect(iconShadows, isNotNull);
    expect(textShadows, hasLength(2));
    expect(iconShadows, hasLength(2));
    expect(textShadows!.last.blurRadius, lessThanOrEqualTo(20));
    expect(iconShadows!.last.blurRadius, lessThanOrEqualTo(20));

    await gesture.up();
  });

  testWidgets('StellarButton does not use legacy warm glass gradient',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkInternals,
        home: Scaffold(
          body: StellarButton(
            label: 'Сохранить',
            icon: Icons.check_rounded,
            onPressed: () {},
          ),
        ),
      ),
    );

    final decorated = tester.widget<Container>(
      find.byKey(const ValueKey('stellar-button-surface')),
    );
    final decoration = decorated.decoration! as BoxDecoration;

    expect(decoration.gradient, isNot(NebulaColors.warmGlass));
  });
}
