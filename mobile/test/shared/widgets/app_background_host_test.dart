import 'package:cosmo_studio/core/theme/app_visual_mode.dart';
import 'package:cosmo_studio/shared/widgets/ascii_water_background.dart';
import 'package:cosmo_studio/shared/widgets/app_background_host.dart';
import 'package:cosmo_studio/shared/widgets/nebula_background.dart';
import 'package:cosmo_studio/shared/widgets/path_field_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AppBackgroundHost uses dark Nebula background by default',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppBackgroundHost(
            child: Text('content'),
          ),
        ),
      ),
    );

    expect(find.byType(NebulaBackground), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets(
      'AppBackgroundHost uses an ambient animated path field for light lite mode',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVisualModeProvider.overrideWith((ref) => AppVisualMode.lightLite),
        ],
        child: const MaterialApp(
          home: AppBackgroundHost(
            child: Text('content'),
          ),
        ),
      ),
    );

    final background = tester.widget<PathFieldBackground>(
      find.byType(PathFieldBackground),
    );

    expect(background.animated, isTrue);
    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('AppBackgroundHost can host the existing ASCII dark background',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AppBackgroundHost(
            darkBackground: AppDarkBackground.asciiWater,
            child: Text('content'),
          ),
        ),
      ),
    );

    expect(find.byType(AsciiWaterBackground), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });
}
