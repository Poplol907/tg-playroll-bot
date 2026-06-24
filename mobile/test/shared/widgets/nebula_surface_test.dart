import 'package:cosmo_studio/shared/widgets/nebula_surface.dart';
import 'package:cosmo_studio/core/theme/nebula_surface_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NebulaSurface paints rounded specular border without assertion',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NebulaSurface(
              child: Text('surface'),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('surface'), findsOneWidget);
  });

  testWidgets('NebulaSurface is blur-free by default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NebulaSurface(
              child: Text('cheap surface'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('NebulaSurface can opt into frosted blur', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NebulaSurface(
              frosted: true,
              child: Text('frosted surface'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('NebulaSurface frostedSmall profile is explicit blur opt-in',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NebulaSurface(
              profile: NebulaSurfaceProfile.frostedSmall,
              child: Text('frosted profile'),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('NebulaSurface circle keeps decoration and clip geometry aligned',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: NebulaSurface(
              width: 38,
              height: 38,
              shape: BoxShape.circle,
              child: Icon(Icons.chevron_left_rounded),
            ),
          ),
        ),
      ),
    );

    final decoratedContainers = tester
        .widgetList<Container>(find.byType(Container))
        .where((container) => container.decoration is BoxDecoration)
        .map((container) => container.decoration! as BoxDecoration)
        .where((decoration) => decoration.shape == BoxShape.circle);

    expect(decoratedContainers, hasLength(2));
    expect(find.byType(ClipOval), findsOneWidget);
    expect(find.byType(ClipRRect), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
