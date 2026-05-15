import 'package:flutter/material.dart';

import 'nebula_tokens.dart';

/// Component style "configs" — pure data classes that describe how a
/// reusable primitive should look. The widgets that render them are
/// stateless renderers (dumb pipes) — change the look here, the whole
/// app updates.
///
/// SOLID notes:
/// - **DIP**: primitives (`StatusBadge`, `AppErrorCard`, `IconCallout`)
///   accept a `*Style` argument. They never compute geometry or sizes.
/// - **OCP**: a designer wants more compact badges? Pass a custom
///   `BadgeStyle(...)` once, or override `NebulaComponentStyles.badge`.
/// - **SRP**: this file is about geometry/dimensions of named components.
///   Colors live in `NebulaSemantic`. Surfaces in `NebulaSurfaceProfile`.

@immutable
class BadgeStyle {
  final double height;
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double iconGap;
  final BorderRadius borderRadius;

  const BadgeStyle({
    required this.height,
    required this.padding,
    required this.iconSize,
    required this.iconGap,
    required this.borderRadius,
  });

  static const BadgeStyle compact = BadgeStyle(
    height: 22,
    padding: EdgeInsets.symmetric(horizontal: NebulaTokens.sp8),
    iconSize: 12,
    iconGap: NebulaTokens.sp4,
    borderRadius: BorderRadius.all(Radius.circular(NebulaTokens.radiusXS)),
  );

  static const BadgeStyle regular = BadgeStyle(
    height: 28,
    padding: EdgeInsets.symmetric(
      horizontal: NebulaTokens.sp12,
      vertical: 4,
    ),
    iconSize: 14,
    iconGap: NebulaTokens.sp4 + 2,
    borderRadius: BorderRadius.all(Radius.circular(NebulaTokens.radiusSM)),
  );
}

@immutable
class IconCalloutStyle {
  /// Size of the circular icon "puck".
  final double iconBoxSize;
  final double iconSize;
  /// Spacing between the icon puck and the textual content.
  final double gap;
  /// Padding around the whole callout when rendered as a card row.
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  const IconCalloutStyle({
    required this.iconBoxSize,
    required this.iconSize,
    required this.gap,
    required this.padding,
    required this.borderRadius,
  });

  static const IconCalloutStyle regular = IconCalloutStyle(
    iconBoxSize: 44,
    iconSize: 20,
    gap: NebulaTokens.sp12 + 2, // 14
    padding: EdgeInsets.symmetric(
      horizontal: NebulaTokens.sp16,
      vertical: 14,
    ),
    borderRadius: BorderRadius.all(Radius.circular(NebulaTokens.radiusMD)),
  );

  static const IconCalloutStyle compact = IconCalloutStyle(
    iconBoxSize: 32,
    iconSize: 16,
    gap: NebulaTokens.sp8,
    padding: EdgeInsets.symmetric(
      horizontal: NebulaTokens.sp12,
      vertical: NebulaTokens.sp8,
    ),
    borderRadius: BorderRadius.all(Radius.circular(NebulaTokens.radiusSM)),
  );
}

@immutable
class ErrorCardStyle {
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double retryButtonHeight;

  const ErrorCardStyle({
    required this.padding,
    required this.iconSize,
    required this.retryButtonHeight,
  });

  static const ErrorCardStyle regular = ErrorCardStyle(
    padding: EdgeInsets.symmetric(
      horizontal: NebulaTokens.sp24,
      vertical: NebulaTokens.sp20,
    ),
    iconSize: 40,
    retryButtonHeight: 40,
  );
}

@immutable
class EmptyStateStyle {
  final EdgeInsetsGeometry padding;
  final double iconSize;
  final double iconToTitleGap;
  final double titleToSubtitleGap;

  const EmptyStateStyle({
    required this.padding,
    required this.iconSize,
    required this.iconToTitleGap,
    required this.titleToSubtitleGap,
  });

  static const EmptyStateStyle regular = EmptyStateStyle(
    padding: EdgeInsets.all(NebulaTokens.sp32),
    iconSize: 48,
    iconToTitleGap: NebulaTokens.sp12,
    titleToSubtitleGap: 6,
  );
}

@immutable
class MetricStyle {
  final double valueSizeBoost; // multiplier over typography.titleM.fontSize
  final double labelSizeBoost; // multiplier over typography.labelS.fontSize
  final double valueToLabelGap;

  const MetricStyle({
    required this.valueSizeBoost,
    required this.labelSizeBoost,
    required this.valueToLabelGap,
  });

  static const MetricStyle regular = MetricStyle(
    valueSizeBoost: 1.0,
    labelSizeBoost: 1.0,
    valueToLabelGap: 2,
  );
}

@immutable
class ActionRowStyle {
  final EdgeInsetsGeometry padding;
  final double iconBoxSize;
  final double iconSize;
  final double iconGap;
  final BorderRadius borderRadius;

  const ActionRowStyle({
    required this.padding,
    required this.iconBoxSize,
    required this.iconSize,
    required this.iconGap,
    required this.borderRadius,
  });

  static const ActionRowStyle regular = ActionRowStyle(
    padding: EdgeInsets.symmetric(
      horizontal: NebulaTokens.sp16,
      vertical: 14,
    ),
    iconBoxSize: 36,
    iconSize: 18,
    iconGap: NebulaTokens.sp12 + 2,
    borderRadius: BorderRadius.all(Radius.circular(NebulaTokens.radiusMD)),
  );
}

/// Aggregate component-style bag. Theme registers one instance and any
/// primitive resolves via `NebulaComponentStyles.of(context).badge`.
class NebulaComponentStyles extends ThemeExtension<NebulaComponentStyles> {
  final BadgeStyle badge;
  final IconCalloutStyle callout;
  final ErrorCardStyle errorCard;
  final EmptyStateStyle emptyState;
  final MetricStyle metric;
  final ActionRowStyle actionRow;

  const NebulaComponentStyles({
    required this.badge,
    required this.callout,
    required this.errorCard,
    required this.emptyState,
    required this.metric,
    required this.actionRow,
  });

  static const NebulaComponentStyles regular = NebulaComponentStyles(
    badge: BadgeStyle.regular,
    callout: IconCalloutStyle.regular,
    errorCard: ErrorCardStyle.regular,
    emptyState: EmptyStateStyle.regular,
    metric: MetricStyle.regular,
    actionRow: ActionRowStyle.regular,
  );

  /// Convenience accessor — falls back to the regular preset.
  static NebulaComponentStyles of(BuildContext context) =>
      Theme.of(context).extension<NebulaComponentStyles>() ?? regular;

  @override
  NebulaComponentStyles copyWith({
    BadgeStyle? badge,
    IconCalloutStyle? callout,
    ErrorCardStyle? errorCard,
    EmptyStateStyle? emptyState,
    MetricStyle? metric,
    ActionRowStyle? actionRow,
  }) {
    return NebulaComponentStyles(
      badge: badge ?? this.badge,
      callout: callout ?? this.callout,
      errorCard: errorCard ?? this.errorCard,
      emptyState: emptyState ?? this.emptyState,
      metric: metric ?? this.metric,
      actionRow: actionRow ?? this.actionRow,
    );
  }

  @override
  NebulaComponentStyles lerp(
    ThemeExtension<NebulaComponentStyles>? other,
    double t,
  ) {
    // Component sizes are discrete recipes; interpolating them just
    // produces visual jank. Snap on the second half of the animation.
    if (other is! NebulaComponentStyles) return this;
    return t < 0.5 ? this : other;
  }
}
