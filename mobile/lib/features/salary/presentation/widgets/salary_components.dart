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
                      color: color.withValues(alpha: 0.40),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.50),
                      blurRadius: 2,
                    ),
                    BoxShadow(
                      color: color.withValues(alpha: 0.70),
                      blurRadius: 7,
                    ),
                  ],
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: tokens.mutedText,
              ),
            ),
            Text(
              '$value сум',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
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
    return NebulaSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: NebulaTokens.radiusMD,
      accent: color,
      glow: [
        BoxShadow(
          color: color.withValues(alpha: isLight ? 0.15 : 0.20),
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
            shadows: isLight
                ? null
                : [
                    Shadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 2),
                    Shadow(
                        color: color.withValues(alpha: 0.7), blurRadius: 10),
                  ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: color,
              shadows: isLight
                  ? null
                  : [
                      Shadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          blurRadius: 2),
                      Shadow(
                          color: color.withValues(alpha: 0.5), blurRadius: 8),
                    ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.secondaryText,
              letterSpacing: 0.2,
            ),
          ),
          Text(
            sublabel,
            style: TextStyle(
              fontSize: 10,
              color: tokens.mutedText,
            ),
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
    return NebulaSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: NebulaTokens.radiusSM,
      accent: NebulaColors.auroraCyan,
      child: Row(
        children: [
          const Icon(
            Icons.repeat_rounded,
            color: NebulaColors.auroraCyan,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Отработано $count урок${_plural(count)}: педагог закрыл долги ✓',
              style: const TextStyle(
                fontSize: 13,
                color: NebulaColors.auroraCyan,
              ),
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
    return NebulaSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: NebulaTokens.radiusSM,
      accent: NebulaColors.errorRose,
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: NebulaColors.errorRose,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Долг: $count урок${_plural(count)} отменено педагогом без отработки',
              style: const TextStyle(
                fontSize: 13,
                color: NebulaColors.errorRose,
              ),
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
    return NebulaSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: NebulaTokens.radiusSM,
      accent: NebulaColors.warningAmber,
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: NebulaColors.warningAmber,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$amount сум — пропуски ученика, будут зачислены в конце месяца',
              style: const TextStyle(
                fontSize: 13,
                color: NebulaColors.warningAmber,
              ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? tokens.primaryText : tokens.mutedText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: FontWeight.w700,
            color: color,
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
    return NebulaSurface(
      padding: const EdgeInsets.all(20),
      borderRadius: NebulaTokens.radiusLG,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.tune_rounded, color: tokens.primaryAccent, size: 16),
            const SizedBox(width: 8),
            Text(
              'КОНФИГУРАЦИЯ СТАВОК',
              style: TextStyle(
                fontSize: 11,
                color: tokens.primaryAccent,
                letterSpacing: 0.8,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          ...rates.asMap().entries.map((e) {
            final i = e.key;
            final r = e.value;
            final Color dotColor = r.isForeign
                ? NebulaColors.warningAmber
                : NebulaColors.stellarBlue;
            final String label = r.isForeign
                ? 'Иностранный тариф'
                : (r.instrumentName ?? 'Базовая ставка');
            return Column(
              children: [
                if (i > 0)
                  const Divider(color: NebulaColors.surfaceBorder, height: 16),
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
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: r.isForeign
                                ? tokens.warning
                                : tokens.primaryText,
                          ),
                        ),
                        if (r.note.isNotEmpty)
                          Text(
                            r.note,
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.mutedText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${fmt(r.ratePerLesson)} сум',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dotColor,
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
      borderRadius: NebulaTokens.radiusLG,
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
            style: TextStyle(
              color: tokens.secondaryText,
              fontSize: 13,
            ),
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
    return NebulaSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: NebulaTokens.radiusMD,
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: NebulaColors.warningAmber,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: NebulaColors.mistWhite,
                fontSize: 12,
              ),
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
