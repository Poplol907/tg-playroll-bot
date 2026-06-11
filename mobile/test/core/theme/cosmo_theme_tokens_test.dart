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
    expect(CosmoThemeTokens.lightLite.background, const Color(0xFFFFF8EC));
    expect(CosmoThemeTokens.lightLite.primaryText, const Color(0xFF211A12));
  });

  test('light tokens use warm sand canvas with vivid shared accents', () {
    final liteBg = CosmoThemeTokens.lightLite.background;
    final liteSurface = CosmoThemeTokens.lightLite.surface;

    int red(Color color) => (color.r * 255).round();
    int green(Color color) => (color.g * 255).round();
    int blue(Color color) => (color.b * 255).round();

    expect(red(liteBg), greaterThan(blue(liteBg)));
    expect(green(liteBg), greaterThan(blue(liteBg)));
    expect(red(liteSurface), greaterThan(blue(liteSurface)));
    expect(CosmoThemeTokens.lightLite.success, NebulaColors.successMint);
    expect(CosmoThemeTokens.lightLite.warning, NebulaColors.warningAmber);
    expect(CosmoThemeTokens.lightLite.error, NebulaColors.errorRose);
  });

  test('light theme tokens keep glow intensity restrained', () {
    expect(CosmoThemeTokens.darkInternals.glowIntensity, 1.0);
    expect(CosmoThemeTokens.lightLite.glowIntensity,
        lessThan(CosmoThemeTokens.darkInternals.glowIntensity));
  });
}
