import 'dart:io';

import 'package:cosmo_studio/shared/widgets/app_chrome_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route content reservation is derived from rendered top chrome', () {
    expect(
      AppChromeMetrics.mobileTopIslandExtent,
      AppChromeMetrics.mobileTopIslandVisualHeight +
          (AppChromeMetrics.mobileTopIslandOuterVerticalGap * 2),
    );
    expect(
      AppChromeMetrics.routeContentTopReservation,
      AppChromeMetrics.mobileTopIslandExtent,
    );
  });

  test('AppSafeInsets delegates shell reservations to AppChromeMetrics', () {
    final source = File(
      'lib/shared/widgets/app_safe_layout.dart',
    ).readAsStringSync();

    expect(source, contains('AppChromeMetrics.routeContentTopReservation'));
    expect(source, contains('AppChromeMetrics.floatingBottomNavReservation'));
    expect(source, isNot(contains('Approximate height')));
    expect(source, isNot(contains('floatingTopBarHeight')));
    expect(source, isNot(contains('floatingNavBarHeight')));
  });
}
