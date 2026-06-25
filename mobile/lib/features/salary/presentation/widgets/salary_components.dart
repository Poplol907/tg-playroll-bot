part of '../screens/salary_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendDot({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: NebulaAlpha.medium),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: NebulaAlpha.strong),
                      blurRadius: 2,
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: NebulaAlpha.high),
                      blurRadius: 7,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelS.copyWith(color: tokens.mutedText),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '$value ${Money.active.symbol}',
                  maxLines: 1,
                  style: type.labelM.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sublabel;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sublabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return NebulaSurface(
      padding: const EdgeInsets.all(14),
      accent: color,
      glow: [
        BoxShadow(
          color: color.withValues(
              alpha: isLight ? NebulaAlpha.subtle : NebulaAlpha.border),
          blurRadius: isLight ? 32 : 18,
          spreadRadius: isLight ? -6 : 0,
          offset: Offset.zero,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
            // Light: soft scattered glow (wide blur, low alpha) — the icon's
            // light diffuses gently into the matte surface instead of sitting
            // flat or casting a hard halo.
            shadows: isLight
                ? [
                    Shadow(
                        color: color.withValues(alpha: NebulaAlpha.accent),
                        blurRadius: 10),
                    Shadow(
                        color: color.withValues(alpha: NebulaAlpha.subtle),
                        blurRadius: 24),
                  ]
                : [
                    Shadow(
                        color:
                            Colors.white.withValues(alpha: NebulaAlpha.strong),
                        blurRadius: 2),
                    Shadow(
                        color: color.withValues(alpha: NebulaAlpha.high),
                        blurRadius: 10),
                  ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: type.displayL.copyWith(
                color: color,
                shadows: isLight
                    ? null
                    : [
                        Shadow(
                            color: Colors.white
                                .withValues(alpha: NebulaAlpha.medium),
                            blurRadius: 2),
                        Shadow(
                            color: color.withValues(alpha: NebulaAlpha.strong),
                            blurRadius: 8),
                      ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: type.labelS.copyWith(
              fontWeight: FontWeight.w600,
              color: tokens.secondaryText,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            sublabel,
            style: type.overline.copyWith(color: tokens.mutedText),
          ),
        ],
      ),
    );
  }
}

class _MakeupBanner extends StatelessWidget {
  final int count;
  const _MakeupBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radiusRole: NebulaRadiusRole.control,
      accent: tokens.focusAccent,
      child: Row(
        children: [
          Icon(
            Icons.repeat_rounded,
            color: tokens.focusAccent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Отработано $count урок${_plural(count)}: педагог закрыл долги ✓',
              style: NebulaTypography.of(context)
                  .bodyS
                  .copyWith(color: tokens.focusAccent),
            ),
          ),
        ],
      ),
    );
  }

  static String _plural(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'а';
    }
    return 'ов';
  }
}

class _DebtBanner extends StatelessWidget {
  final int count;
  const _DebtBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radiusRole: NebulaRadiusRole.control,
      accent: tokens.error,
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: tokens.error,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Долг: $count урок${_plural(count)} отменено педагогом без отработки',
              style: NebulaTypography.of(context)
                  .bodyS
                  .copyWith(color: tokens.error),
            ),
          ),
        ],
      ),
    );
  }

  static String _plural(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'а';
    }
    return 'ов';
  }
}

class _PendingBanner extends StatelessWidget {
  final String amount;
  const _PendingBanner({required this.amount});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radiusRole: NebulaRadiusRole.control,
      accent: tokens.warning,
      child: Row(
        children: [
          Icon(
            Icons.schedule_rounded,
            color: tokens.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$amount — пропуски ученика, будут зачислены в конце месяца',
              style: NebulaTypography.of(context)
                  .bodyS
                  .copyWith(color: tokens.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool bold;

  const _PayRow({
    required this.label,
    required this.value,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (bold ? type.titleM : type.bodyM).copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: bold ? tokens.primaryText : tokens.mutedText,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: (bold ? type.titleM : type.bodyM).copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RatesCard extends StatelessWidget {
  final List<RateEntry> rates;
  final String Function(int) fmt;
  const _RatesCard({required this.rates, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return NebulaSurface(
      padding: const EdgeInsets.all(20),
      radiusRole: NebulaRadiusRole.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.tune_rounded, color: tokens.primaryAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              'КОНФИГУРАЦИЯ СТАВОК',
              style: type.overline.copyWith(color: tokens.primaryAccent),
            ),
          ]),
          const SizedBox(height: 14),
          if (rates.isEmpty)
            Text(
              'Ставки пока не настроены',
              style: type.bodyM.copyWith(color: tokens.mutedText),
            ),
          ...rates.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            final Color dotColor =
                r.isForeign ? tokens.warning : tokens.primaryAccent;
            final String label = r.isForeign
                ? 'Иностранный тариф'
                : (r.instrumentName ?? 'Базовая ставка');
            return Column(
              children: [
                if (i > 0) Divider(color: tokens.surfaceBorder, height: 16),
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: type.bodyM.copyWith(
                            fontWeight: FontWeight.w600,
                            color: r.isForeign
                                ? tokens.warning
                                : tokens.primaryText,
                          ),
                        ),
                        if (r.note.isNotEmpty)
                          Text(
                            r.note,
                            style:
                                type.labelS.copyWith(color: tokens.mutedText),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${fmt(r.ratePerLesson)} ${Money.active.symbol}',
                        maxLines: 1,
                        style: type.bodyM.copyWith(
                          fontWeight: FontWeight.w700,
                          color: dotColor,
                        ),
                      ),
                    ),
                  ),
                ]),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Empty / error states
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaSurface(
      padding: const EdgeInsets.all(24),
      radiusRole: NebulaRadiusRole.panel,
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: tokens.mutedText,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Ошибка загрузки',
            style: TextStyle(color: tokens.error),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: NebulaTypography.of(context)
                .bodyS
                .copyWith(color: tokens.secondaryText),
          ),
          const SizedBox(height: 12),
          NebulaTextButton(
            label: 'Повторить',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}

class _InlineErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineErrorCard({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaSurface(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: tokens.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: NebulaTypography.of(context)
                  .labelM
                  .copyWith(color: tokens.secondaryText),
            ),
          ),
          NebulaTextButton(
            label: 'Повторить',
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            compact: true,
          ),
        ],
      ),
    );
  }
}
