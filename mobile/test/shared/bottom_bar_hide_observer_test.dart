import 'package:cosmo_studio/shared/providers/bottom_bar_visibility_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _buildRouter(BottomBarHideObserver observer) {
  return GoRouter(
    initialLocation: '/a',
    observers: [observer],
    routes: [
      ShellRoute(
        builder: (context, state, child) => Scaffold(body: child),
        routes: [
          GoRoute(
            path: '/a',
            pageBuilder: (c, s) => const NoTransitionPage(child: Text('A')),
          ),
          GoRoute(
            path: '/b',
            pageBuilder: (c, s) => const NoTransitionPage(child: Text('B')),
          ),
        ],
      ),
    ],
  );
}

void main() {
  testWidgets(
      'view-as flow regression: root push + pop + go() leaves the bar visible',
      (tester) async {
    var barVisible = true;
    final observer = BottomBarHideObserver((v) => barVisible = v);
    final router = _buildRouter(observer);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(barVisible, isTrue);

    // Full-screen pageless push (как teacher profile на root-навигаторе).
    Navigator.of(tester.element(find.text('A')), rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => const Text('profile')),
    );
    await tester.pumpAndSettle();
    expect(barVisible, isFalse);

    // «Открыть как педагог»: pop профиля + go на другую вкладку в одном
    // кадре. Раньше pages-diff внутри go() утекал в счётчик глубины и бар
    // оставался спрятанным навсегда.
    Navigator.pop(tester.element(find.text('profile')));
    router.go('/b');
    await tester.pumpAndSettle();

    expect(find.text('B'), findsOneWidget);
    expect(barVisible, isTrue);
  });

  testWidgets('tab switches via go() never hide the bar', (tester) async {
    var barVisible = true;
    final observer = BottomBarHideObserver((v) => barVisible = v);
    final router = _buildRouter(observer);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    router.go('/b');
    await tester.pumpAndSettle();
    expect(barVisible, isTrue);

    router.go('/a');
    await tester.pumpAndSettle();
    expect(barVisible, isTrue);
  });

  testWidgets('sheet hides the bar, closing it restores the bar',
      (tester) async {
    var barVisible = true;
    final observer = BottomBarHideObserver((v) => barVisible = v);
    final router = _buildRouter(observer);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('A'));
    // The observer is attached to the ROOT navigator; sheets opened on the
    // shell's nested navigator are covered by runWithBottomBarHidden instead.
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const SizedBox(height: 120, child: Text('sheet')),
    );
    await tester.pumpAndSettle();
    expect(barVisible, isFalse);

    Navigator.pop(tester.element(find.text('sheet')));
    await tester.pumpAndSettle();
    expect(barVisible, isTrue);
  });
}
