import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/cosmo_theme_tokens.dart';
import 'package:cosmo_studio/core/theme/nebula_alpha.dart';
import 'package:cosmo_studio/core/theme/nebula_semantic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SemanticRole.fromBase derives tint/border/glow via NebulaAlpha', () {
    const base = Color(0xFFAABBCC);
    final r = SemanticRole.fromBase(base);
    expect(r.tint.a, closeTo(NebulaAlpha.surface, 1e-6));
    expect(r.border.a, closeTo(NebulaAlpha.accent, 1e-6));
    expect(r.glow.a, closeTo(NebulaAlpha.subtle, 1e-6));
    // base + contrast stay opaque
    expect(r.base.a, 1);
    expect(r.contrast.a, 1);
  });

  test('fromTokens maps every intent', () {
    final s = NebulaSemantic.fromTokens(CosmoThemeTokens.darkInternals);
    expect(s.primary.base, CosmoThemeTokens.darkInternals.primaryAccent);
    expect(s.info.base, CosmoThemeTokens.darkInternals.focusAccent);
    expect(s.success.base, CosmoThemeTokens.darkInternals.success);
    expect(s.warning.base, CosmoThemeTokens.darkInternals.warning);
    expect(s.danger.base, CosmoThemeTokens.darkInternals.error);
    expect(s.neutral.base, isNotNull);
  });

  test('byIntent returns the matching role', () {
    final s = NebulaSemantic.fromTokens(CosmoThemeTokens.darkInternals);
    expect(s.byIntent(SemanticIntent.primary), s.primary);
    expect(s.byIntent(SemanticIntent.success), s.success);
    expect(s.byIntent(SemanticIntent.danger), s.danger);
  });

  testWidgets('AppTheme registers NebulaSemantic for dark theme',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.dark, home: const SizedBox()),
    );
    final ctx = tester.element(find.byType(SizedBox));
    expect(Theme.of(ctx).extension<NebulaSemantic>(), isNotNull);
  });
}
