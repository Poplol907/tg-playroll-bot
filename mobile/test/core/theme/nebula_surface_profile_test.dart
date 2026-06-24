import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/core/theme/nebula_radii.dart';
import 'package:cosmo_studio/core/theme/nebula_surface_profile.dart';
import 'package:cosmo_studio/shared/widgets/nebula_modal_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  int red(Color color) => (color.r * 255).round();
  int green(Color color) => (color.g * 255).round();
  int blue(Color color) => (color.b * 255).round();

  Future<T> resolveWith<T>(
    WidgetTester tester,
    ThemeData theme,
    T Function(BuildContext context) resolver,
  ) async {
    late T result;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: theme,
          child: Builder(
            builder: (context) {
              result = resolver(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return result;
  }

  testWidgets(
    'surface profiles resolve fill and border from active theme tokens',
    (tester) async {
      final lightCard = await resolveWith(
        tester,
        AppTheme.lightLite,
        (context) => NebulaSurfaceProfile.card.resolve(context),
      );

      final darkCard = await resolveWith(
        tester,
        AppTheme.darkInternals,
        (context) => NebulaSurfaceProfile.card.resolve(context),
      );

      expect(lightCard.fill, CosmoThemeTokens.lightLite.surface);
      expect(lightCard.border, CosmoThemeTokens.lightLite.surfaceBorder);
      expect(darkCard.fill, CosmoThemeTokens.darkInternals.surface);
      expect(darkCard.border, CosmoThemeTokens.darkInternals.surfaceBorder);
    },
  );

  testWidgets('default surface profiles do not enable blur', (tester) async {
    final styles = await resolveWith(
      tester,
      AppTheme.lightLite,
      (context) => [
        NebulaSurfaceProfile.card.resolve(context),
        NebulaSurfaceProfile.panel.resolve(context),
        NebulaSurfaceProfile.modal.resolve(context),
        NebulaSurfaceProfile.input.resolve(context),
        NebulaSurfaceProfile.nav.resolve(context),
        NebulaSurfaceProfile.status.resolve(context),
      ],
    );

    for (final style in styles) {
      expect(style.blurPolicy, NebulaBlurPolicy.none);
      expect(style.blurSigma, 0);
    }
  });

  for (final theme in [AppTheme.lightLite, AppTheme.darkInternals]) {
    testWidgets(
      'surface profiles resolve semantic radii in ${theme.brightness.name}',
      (tester) async {
        final radii = await resolveWith(
          tester,
          theme,
          (context) => {
            for (final profile in NebulaSurfaceProfile.values)
              profile: profile.resolve(context).radius,
          },
        );

        expect(radii[NebulaSurfaceProfile.input], NebulaRadii.control);
        expect(radii[NebulaSurfaceProfile.status], NebulaRadii.control);
        expect(radii[NebulaSurfaceProfile.card], NebulaRadii.card);
        expect(radii[NebulaSurfaceProfile.frostedSmall], NebulaRadii.card);
        expect(radii[NebulaSurfaceProfile.panel], NebulaRadii.panel);
        expect(radii[NebulaSurfaceProfile.modal], NebulaRadii.modal);
        expect(radii[NebulaSurfaceProfile.nav], NebulaRadii.nav);
      },
    );
  }

  testWidgets('frostedSmall is the explicit blur profile', (tester) async {
    final style = await resolveWith(
      tester,
      AppTheme.darkInternals,
      (context) => NebulaSurfaceProfile.frostedSmall.resolve(context),
    );

    expect(style.blurPolicy, NebulaBlurPolicy.explicit);
    expect(style.blurSigma, greaterThan(0));
  });

  testWidgets('modal outer decoration, clip, and sheen share one radius',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: NebulaModalSurface(
            chrome: NebulaModalChrome.dialog,
            child: SizedBox.shrink(),
          ),
        ),
      ),
    );

    final decorations = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .where((decoration) => decoration.borderRadius != null)
        .toList();
    final clip = tester.widget<ClipRRect>(find.byType(ClipRRect));

    expect(decorations, hasLength(2));
    expect(decorations.first.borderRadius, NebulaRadii.modalBorder);
    expect(decorations.last.borderRadius, decorations.first.borderRadius);
    expect(clip.borderRadius, decorations.first.borderRadius);
  });

  testWidgets('light surface profiles use clean warm sand material',
      (tester) async {
    final styles = await resolveWith(
      tester,
      AppTheme.lightLite,
      (context) => [
        NebulaSurfaceProfile.card.resolve(context),
        NebulaSurfaceProfile.panel.resolve(context),
        NebulaSurfaceProfile.modal.resolve(context),
        NebulaSurfaceProfile.input.resolve(context),
        NebulaSurfaceProfile.nav.resolve(context),
      ],
    );

    for (final style in styles) {
      expect(red(style.fill), greaterThanOrEqualTo(green(style.fill)));
      expect(green(style.fill), greaterThan(blue(style.fill)));
      expect(blue(style.fill), greaterThan(235));
    }
  });
}
