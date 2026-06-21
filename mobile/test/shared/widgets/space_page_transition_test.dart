import 'package:cosmo_studio/shared/widgets/space_page_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('shell pages do not replay an entrance transition after a swipe', () {
    final page = shellPage<void>(
      key: const ValueKey('shell-page'),
      child: const Text('foreground'),
    );

    expect(page, isA<NoTransitionPage<void>>());
  });
}
