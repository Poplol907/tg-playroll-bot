import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/core/theme/nebula_surface_profile.dart';
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

  testWidgets('frostedSmall is the explicit blur profile', (tester) async {
    final style = await resolveWith(
      tester,
      AppTheme.darkInternals,
      (context) => NebulaSurfaceProfile.frostedSmall.resolve(context),
    );

    expect(style.blurPolicy, NebulaBlurPolicy.explicit);
    expect(style.blurSigma, greaterThan(0));
  });

  testWidgets('light surface profiles stay cool instead of beige',
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
      expect(blue(style.fill), greaterThanOrEqualTo(red(style.fill)));
      expect(green(style.fill), greaterThanOrEqualTo(red(style.fill)));
    }
  });
}
