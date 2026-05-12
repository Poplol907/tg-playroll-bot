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
    expect(tokens.surface, NebulaColors.nebulaSurface);
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
    expect(CosmoThemeTokens.lightShader.background, const Color(0xFFFAFAF7));
    expect(CosmoThemeTokens.lightLite.background, const Color(0xFFFFFFFF));
    expect(CosmoThemeTokens.lightShader.primaryText, const Color(0xFF171717));
  });

  test('light theme tokens keep glow intensity restrained', () {
    expect(CosmoThemeTokens.darkInternals.glowIntensity, 1.0);
    expect(CosmoThemeTokens.lightShader.glowIntensity, lessThan(0.35));
    expect(CosmoThemeTokens.lightLite.glowIntensity,
        lessThan(CosmoThemeTokens.lightShader.glowIntensity));
  });
}
