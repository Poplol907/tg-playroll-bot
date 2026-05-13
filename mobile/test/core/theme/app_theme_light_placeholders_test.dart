import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light shader placeholder exposes a light theme with semantic tokens',
      () {
    final theme = AppTheme.lightShader;
    final tokens = theme.extension<CosmoThemeTokens>();

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF8FAFF));
    expect(tokens, CosmoThemeTokens.lightShader);
  });

  test('light lite placeholder exposes a lower-load light theme', () {
    final theme = AppTheme.lightLite;
    final tokens = theme.extension<CosmoThemeTokens>();

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(tokens, CosmoThemeTokens.lightLite);
  });
}
