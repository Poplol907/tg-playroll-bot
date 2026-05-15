import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/nebula_semantic.dart';
import 'package:cosmo_studio/shared/widgets/primitives/primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('StatusBadge renders label and icon', (tester) async {
    await tester.pumpWidget(
      _wrap(const StatusBadge(
        label: 'OK',
        icon: Icons.check_rounded,
        intent: SemanticIntent.success,
      )),
    );
    expect(find.text('OK'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('IconCallout shows title, subtitle, trailing, and reacts to tap',
      (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(IconCallout(
        icon: Icons.school_outlined,
        title: 'Али',
        subtitle: '64 урока',
        intent: SemanticIntent.info,
        onTap: () => tapped = true,
        trailing: const Icon(Icons.chevron_right_rounded),
      )),
    );
    expect(find.text('Али'), findsOneWidget);
    expect(find.text('64 урока'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.text('Али'));
    expect(tapped, isTrue);
  });

  testWidgets('MetricStat shows label and value', (tester) async {
    await tester.pumpWidget(
      _wrap(const MetricStat(
        label: 'Уроков',
        value: '64',
        intent: SemanticIntent.primary,
      )),
    );
    expect(find.text('Уроков'), findsOneWidget);
    expect(find.text('64'), findsOneWidget);
  });

  testWidgets('ActionRow is tappable and shows label/icon', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      _wrap(ActionRow(
        icon: Icons.logout_rounded,
        label: 'Выйти',
        destructive: true,
        onTap: () => tapped = true,
      )),
    );
    expect(find.text('Выйти'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    await tester.tap(find.text('Выйти'));
    expect(tapped, isTrue);
  });
}
