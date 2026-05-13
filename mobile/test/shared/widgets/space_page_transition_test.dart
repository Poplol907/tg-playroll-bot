import 'package:cosmo_studio/shared/widgets/space_page_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget transitionHarness({
    required double animationValue,
    required double secondaryValue,
  }) {
    final page = nebulaFadePage<void>(
      key: const ValueKey('shell-page'),
      child: const Text('foreground'),
    );

    return MaterialApp(
      home: Builder(
        builder: (context) {
          return page.transitionsBuilder(
            context,
            AlwaysStoppedAnimation(animationValue),
            AlwaysStoppedAnimation(secondaryValue),
            page.child,
          );
        },
      ),
    );
  }

  double foregroundOpacity(WidgetTester tester) {
    final opacities = tester.widgetList<Opacity>(find.byType(Opacity));
    return opacities.last.opacity;
  }

  testWidgets(
      'nebulaFadePage fades outgoing foreground through secondaryAnimation',
      (tester) async {
    await tester.pumpWidget(
      transitionHarness(animationValue: 1.0, secondaryValue: 0.0),
    );
    expect(foregroundOpacity(tester), 1.0);

    await tester.pumpWidget(
      transitionHarness(animationValue: 1.0, secondaryValue: 0.38),
    );
    expect(foregroundOpacity(tester), 0.0);
  });

  testWidgets('nebulaFadePage delays incoming foreground until old route exits',
      (tester) async {
    await tester.pumpWidget(
      transitionHarness(animationValue: 0.50, secondaryValue: 0.0),
    );
    expect(foregroundOpacity(tester), 0.0);

    await tester.pumpWidget(
      transitionHarness(animationValue: 1.0, secondaryValue: 0.0),
    );
    expect(foregroundOpacity(tester), 1.0);
  });
}
