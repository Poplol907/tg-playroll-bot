import 'package:flutter/material.dart';

import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_typography.dart';

/// A simple two-or-more segment switcher (pill with a sliding-less active fill).
/// One mechanism for "pick one of N peer views" — reused by the search tab
/// (Педагоги / Ученики) and later the calendar scope switcher.
class NebulaSegmentedControl extends StatelessWidget {
  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const NebulaSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.denseSurface.withValues(alpha: NebulaAlpha.surface),
        borderRadius: NebulaRadii.pillBorder,
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Row(
        children: [
          for (var i = 0; i < segments.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == selectedIndex,
                label: segments[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: i == selectedIndex
                          ? tokens.primaryAccent
                              .withValues(alpha: NebulaAlpha.surface)
                          : Colors.transparent,
                      borderRadius: NebulaRadii.pillBorder,
                    ),
                    alignment: Alignment.center,
                    child: ExcludeSemantics(
                      child: Text(
                        segments[i],
                        style: type.labelM.copyWith(
                          color: i == selectedIndex
                              ? tokens.primaryText
                              : tokens.mutedText,
                          fontWeight: i == selectedIndex
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
