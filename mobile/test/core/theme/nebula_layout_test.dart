import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/nebula_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile preset has no sidebar and prefers sheets', () {
    expect(NebulaLayout.mobile.sidebarWidth, 0);
    expect(NebulaLayout.mobile.prefersDialogs, isFalse);
    expect(NebulaLayout.mobile.tapTargetMin, 44);
  });

  test('desktop preset has sidebar, bigger gutter, dialog preference', () {
    expect(NebulaLayout.desktop.sidebarWidth, greaterThan(0));
    expect(NebulaLayout.desktop.prefersDialogs, isTrue);
    expect(NebulaLayout.desktop.contentMaxWidth, lessThan(double.infinity));
    expect(
      NebulaLayout.desktop.pageGutter,
      greaterThan(NebulaLayout.mobile.pageGutter),
    );
  });

  testWidgets('AppTheme registers NebulaLayout', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const SizedBox(),
      ),
    );
    final ctx = tester.element(find.byType(SizedBox));
    expect(Theme.of(ctx).extension<NebulaLayout>(), isNotNull);
  });

  test('lerp prefers second platform after midpoint', () {
    final mid = NebulaLayout.mobile.lerp(NebulaLayout.desktop, 0.49);
    expect(mid.prefersDialogs, NebulaLayout.mobile.prefersDialogs);
    final late = NebulaLayout.mobile.lerp(NebulaLayout.desktop, 0.51);
    expect(late.prefersDialogs, NebulaLayout.desktop.prefersDialogs);
  });
}
