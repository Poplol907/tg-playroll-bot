import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/app_visual_mode.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('theme mode follows selected visual mode', () {
    expect(AppTheme.themeModeFor(AppVisualMode.darkInternals), ThemeMode.dark);
    expect(AppTheme.themeModeFor(AppVisualMode.lightLite), ThemeMode.light);
  });

  test('light theme selection follows selected visual mode', () {
    expect(
        AppTheme.lightThemeFor(AppVisualMode.lightLite)
            .extension<CosmoThemeTokens>(),
        CosmoThemeTokens.lightLite);
  });
}
