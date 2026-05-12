import 'package:cosmo_studio/core/theme/nebula_colors.dart';
import 'package:cosmo_studio/core/theme/nebula_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
