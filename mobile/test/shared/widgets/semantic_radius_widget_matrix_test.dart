import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/nebula_component_styles.dart';
import 'package:cosmo_studio/core/theme/nebula_radii.dart';
import 'package:cosmo_studio/core/theme/nebula_surface_profile.dart';
import 'package:cosmo_studio/shared/widgets/nebula_input.dart';
import 'package:cosmo_studio/shared/widgets/nebula_modal_surface.dart';
import 'package:cosmo_studio/shared/widgets/nebula_surface.dart';
import 'package:cosmo_studio/shared/widgets/primitives/status_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final theme in [AppTheme.darkInternals, AppTheme.lightLite]) {
    final themeName = theme.brightness.name;

    testWidgets('semantic radius matrix resolves in $themeName',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  NebulaSurface(
                    key: ValueKey('card-surface'),
                    profile: NebulaSurfaceProfile.card,
                    child: SizedBox(width: 80, height: 40),
                  ),
                  NebulaSurface(
                    key: ValueKey('panel-surface'),
                    profile: NebulaSurfaceProfile.panel,
                    child: SizedBox(width: 80, height: 40),
                  ),
                  NebulaInput(key: ValueKey('control-input')),
                  NebulaModalSurface(
                    containerKey: ValueKey('dialog-surface'),
                    chrome: NebulaModalChrome.dialog,
                    child: SizedBox(width: 80, height: 40),
                  ),
                  NebulaModalSurface(
                    containerKey: ValueKey('sheet-surface'),
                    child: SizedBox(width: 80, height: 40),
                  ),
                  StatusBadge(label: 'Активен'),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      void expectSurfaceRadius(Key key, BorderRadius expected) {
        final root = find.byKey(key);
        final clip = tester.widget<ClipRRect>(
          find.descendant(of: root, matching: find.byType(ClipRRect)).first,
        );
        final decorations = tester
            .widgetList<Container>(
              find.descendant(of: root, matching: find.byType(Container)),
            )
            .map((container) => container.decoration)
            .whereType<BoxDecoration>()
            .where((decoration) => decoration.borderRadius != null);
        expect(clip.borderRadius, expected);
        expect(decorations, isNotEmpty);
        for (final decoration in decorations) {
          expect(decoration.borderRadius, expected);
        }
      }

      expectSurfaceRadius(
        const ValueKey('card-surface'),
        NebulaRadii.cardBorder,
      );
      expectSurfaceRadius(
        const ValueKey('panel-surface'),
        NebulaRadii.panelBorder,
      );

      final input = tester.widget<NebulaInput>(
        find.byKey(const ValueKey('control-input')),
      );
      expect(input.borderRadius, NebulaRadii.control);

      for (final entry in const [
        (ValueKey('dialog-surface'), NebulaRadii.modalBorder),
        (ValueKey('sheet-surface'), NebulaRadii.sheetTopBorder),
      ]) {
        final container = tester.widget<Container>(find.byKey(entry.$1));
        final decoration = container.decoration! as BoxDecoration;
        final clip = tester.widget<ClipRRect>(
          find.descendant(
            of: find.byKey(entry.$1),
            matching: find.byType(ClipRRect),
          ),
        );
        expect(decoration.borderRadius, entry.$2);
        expect(clip.borderRadius, entry.$2);
      }

      final badgeDecoration = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .firstWhere(
            (decoration) =>
                decoration.borderRadius == BadgeStyle.regular.borderRadius,
          );
      expect(badgeDecoration.borderRadius, NebulaRadii.pillBorder);
      expect(tester.takeException(), isNull);
    });
  }
}
