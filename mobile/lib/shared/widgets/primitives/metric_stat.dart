import 'package:flutter/material.dart';

import '../../../core/theme/cosmo_theme_tokens.dart';
import '../../../core/theme/nebula_component_styles.dart';
import '../../../core/theme/nebula_semantic.dart';
import '../../../core/theme/nebula_typography.dart';

/// A compact "big number + label" stat tile — replaces the dozens of
/// hand-rolled stat cards spread across the dashboards.
///
/// Example:
///   MetricStat(label: 'Уроков', value: '64', intent: SemanticIntent.primary)
class MetricStat extends StatelessWidget {
  final String label;
  final String value;
  final SemanticIntent intent;
  final MetricStyle? styleOverride;

  const MetricStat({
    super.key,
    required this.label,
    required this.value,
    this.intent = SemanticIntent.primary,
    this.styleOverride,
  });

  @override
  Widget build(BuildContext context) {
    final style = styleOverride ?? NebulaComponentStyles.of(context).metric;
    final role = NebulaSemantic.of(context).byIntent(intent);
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: type.labelS.copyWith(
            color: tokens.mutedText,
            fontSize: type.labelS.fontSize! * style.labelSizeBoost,
          ),
        ),
        SizedBox(height: style.valueToLabelGap),
        // Values like money ("1 234 567 ₽") use non-breaking spaces and can't
        // wrap — scaleDown shrinks an oversized number to fit its column
        // instead of overflowing the row.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: type.titleM.copyWith(
              color: role.contrast,
              fontSize: type.titleM.fontSize! * style.valueSizeBoost,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
