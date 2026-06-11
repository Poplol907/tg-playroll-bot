import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/core/theme/nebula_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dark theme exposes semantic Cosmo theme tokens', () {
    final tokens =
        AppTheme.themeExtensions.whereType<CosmoThemeTokens>().single;

    expect(tokens.background, NebulaColors.deepVoid);
    expect(tokens.surface, const Color(0xE60F1528));
    expect(tokens.primaryAccent, NebulaColors.stellarBlue);
    expect(tokens.success, NebulaColors.successMint);
  });

  test('Cosmo theme tokens support copyWith for targeted overrides', () {
    final tokens = CosmoThemeTokens.darkInternals.copyWith(
      primaryAccent: NebulaColors.auroraCyan,
    );

    expect(tokens.primaryAccent, NebulaColors.auroraCyan);
    expect(tokens.background, CosmoThemeTokens.darkInternals.background);
  });

  test('light placeholder tokens use bright canvas values', () {
    expect(CosmoThemeTokens.lightLite.background, const Color(0xFFFFFFFF));
    expect(CosmoThemeTokens.lightLite.primaryText, const Color(0xFF0D1117));
  });

  test('light tokens stay cool and avoid beige surfaces', () {
    final liteBg = CosmoThemeTokens.lightLite.background;
    final liteSurface = CosmoThemeTokens.lightLite.surface;

    int red(Color color) => (color.r * 255).round();
    int green(Color color) => (color.g * 255).round();
    int blue(Color color) => (color.b * 255).round();

    expect(blue(liteBg), greaterThanOrEqualTo(red(liteBg)));
    expect(green(liteBg), greaterThanOrEqualTo(red(liteBg)));
    expect(blue(liteSurface), greaterThan(red(liteSurface)));
  });

  test('light theme tokens keep glow intensity restrained', () {
    expect(CosmoThemeTokens.darkInternals.glowIntensity, 1.0);
    expect(CosmoThemeTokens.lightLite.glowIntensity,
        lessThan(CosmoThemeTokens.darkInternals.glowIntensity));
  });
}
