import 'package:cosmo_studio/core/theme/nebula_colors.dart';
import 'package:cosmo_studio/core/theme/nebula_radii.dart';
import 'package:cosmo_studio/core/theme/nebula_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('semantic radii expose the canonical application geometry', () {
    expect(NebulaRadii.micro, 4);
    expect(NebulaRadii.control, 12);
    expect(NebulaRadii.card, 18);
    expect(NebulaRadii.panel, 24);
    expect(NebulaRadii.modal, 24);
    expect(NebulaRadii.sheet, 24);
    expect(NebulaRadii.hero, 32);
    expect(NebulaRadii.pill, 999);
    expect(
      NebulaRadii.cardBorder,
      const BorderRadius.all(Radius.circular(18)),
    );
    expect(
      NebulaRadii.pillBorder,
      const BorderRadius.all(Radius.circular(999)),
    );
  });

  test('dark glow presets stay expressive but bounded', () {
    final presets = [
      NebulaTokens.glowSoft(NebulaColors.stellarBlue),
      NebulaTokens.glowMedium(NebulaColors.stellarBlue),
      NebulaTokens.glowFocus(NebulaColors.stellarBlue),
    ];

    for (final preset in presets) {
      expect(preset, hasLength(3));
      for (final shadow in preset) {
        expect(shadow.blurRadius, lessThanOrEqualTo(40));
        expect(shadow.spreadRadius, lessThanOrEqualTo(8));
      }
    }
  });

  test('dark glow presets keep a clear intensity ramp', () {
    final soft = NebulaTokens.glowSoft(NebulaColors.stellarBlue);
    final medium = NebulaTokens.glowMedium(NebulaColors.stellarBlue);
    final focus = NebulaTokens.glowFocus(NebulaColors.stellarBlue);

    expect(soft.last.blurRadius, lessThan(medium.last.blurRadius));
    expect(medium.last.blurRadius, lessThan(focus.last.blurRadius));
  });
}
