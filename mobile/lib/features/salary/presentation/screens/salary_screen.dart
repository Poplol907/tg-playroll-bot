import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../features/admin/presentation/providers/view_as_teacher_provider.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../providers/salary_provider.dart';
import '../../../../shared/providers/data_refresh_provider.dart';
import '../../../../shared/providers/month_provider.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/nebula_text_button.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/app_screen_header.dart';

part '../widgets/salary_components.dart';
part '../widgets/salary_ring.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────────────────────────────────────

class SalaryScreen extends ConsumerWidget {
  const SalaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salaryAsync = ref.watch(salaryProvider);
    final monthYear = ref.watch(globalMonthYearProvider);
    final user = ref.watch(currentUserProvider);
    final viewAs = ref.watch(viewAsTeacherProvider);
    // В режиме view-as заголовок показывает имя педагога, чьи данные смотрим.
    final headerName = viewAs?.displayName ?? user?.displayName ?? '';
    final month = DateFormat('yyyy-MM').parse(monthYear);
    final monthLabel = DateFormat('MMMM yyyy', 'ru').format(month);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: AppScrollView(
          includeKeyboardInset: false,
          padding: AppSafeInsets.screen(
            context,
            bottom: 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppScreenHeader(title: 'Зарплата', subtitle: headerName),
              const SizedBox(height: 24),
              salaryAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(60),
                    child: OrbitLoader(size: 36),
                  ),
                ),
                error: (e, _) => _ErrorCard(
                  message: parseApiError(
                    e,
                    fallback: 'Не удалось загрузить зарплату',
                  ),
                  onRetry: () => ref.invalidate(salaryProvider),
                ),
                data: (data) =>
                    _SalaryContent(data: data, monthLabel: monthLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main salary content
// ─────────────────────────────────────────────────────────────────────────────

class _SalaryContent extends ConsumerStatefulWidget {
  final SalaryData data;
  final String monthLabel;

  const _SalaryContent({required this.data, required this.monthLabel});

  @override
  ConsumerState<_SalaryContent> createState() => _SalaryContentState();
}

class _SalaryContentState extends ConsumerState<_SalaryContent>
    with TickerProviderStateMixin {
  late AnimationController _ringCtrl;
  late AnimationController _breatheCtrl;
  late AnimationController _enterCtrl;
  late AnimationController _waveCtrl;
  late Animation<double> _ringAnim;
  late Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
      value: SalaryRingVisualProfile.staticBreatheValue,
    );
    if (SalaryRingVisualProfile.enableAmbientBreathing) {
      _breatheCtrl.repeat(reverse: true);
    }
    _breatheAnim =
        CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut);

    // Liquid circulation inside the light-theme bubble. Runs only when the
    // bubble is actually shown (gated in didChangeDependencies).
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    );

    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _ringCtrl.forward();
    _enterCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isLight = Theme.of(context).brightness == Brightness.light;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (isLight && !reduceMotion) {
      if (!_waveCtrl.isAnimating) _waveCtrl.repeat();
    } else {
      _waveCtrl
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  void didUpdateWidget(_SalaryContent old) {
    super.didUpdateWidget(old);
    if (old.data.monthYear != widget.data.monthYear) {
      _ringCtrl.forward(from: 0);
      _enterCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _breatheCtrl.dispose();
    _waveCtrl.dispose();
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _resetMonth() async {
    final monthYear = ref.read(globalMonthYearProvider);
    final viewAs = ref.read(viewAsTeacherProvider);
    final month = DateFormat('yyyy-MM').parse(monthYear);
    final monthLabel = DateFormat('MMMM yyyy', 'ru').format(month);

    final confirmed = await NebulaDialog.confirm(
      context,
      title: 'Сбросить данные месяца?',
      message:
          'Все уроки и подписки за $monthLabel будут удалены безвозвратно. Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
      destructive: true,
      icon: Icons.delete_sweep_rounded,
    );

    if (!confirmed || !mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete(
        '/reports/v2/reset-month',
        queryParameters: {
          'month_year': monthYear,
          if (viewAs != null) 'teacher_id': viewAs.id,
        },
      );
      if (!mounted) return;
      invalidateMonthData(ref, monthYear);

      showNebulaSnackBar(
        context,
        title: 'Данные месяца сброшены',
        tone: NebulaSnackTone.success,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      showNebulaSnackBar(
        context,
        title: 'Не удалось сбросить месяц',
        message: 'Ошибка: ${e.response?.data ?? e.message}',
        tone: NebulaSnackTone.error,
      );
    }
  }

  String _fmt(int amount) => Money.amount(amount);

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final ratesAsync = ref.watch(ratesProvider);
    final earnedFrac = d.goalAmount > 0 ? d.earnedAmount / d.goalAmount : 0.0;
    final pendingFrac = d.goalAmount > 0 ? d.pendingAmount / d.goalAmount : 0.0;

    return AnimatedBuilder(
      animation:
          Listenable.merge([_ringAnim, _breatheAnim, _enterCtrl, _waveCtrl]),
      builder: (context, _) {
        final ring = _ringAnim.value;
        final breathe = _breatheAnim.value;

        double eo(double s, double e) =>
            ((_enterCtrl.value - s) / (e - s)).clamp(0.0, 1.0);

        Widget entered(Widget child, double s, double e) {
          final frac = eo(s, e);
          return Opacity(
            opacity: frac,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - frac)),
              child: child,
            ),
          );
        }

        return Column(
          children: [
            // ── Hero gamification card ─────────────────────────────────────
            // Glass island — mint glow spills OUTWARD, surface stays neutral
            entered(
              NebulaSurface(
                padding: const EdgeInsets.all(28),
                radiusRole: NebulaRadiusRole.hero,
                child: Column(
                  children: [
                    // Amount text — glow in dark, clean ink in light.
                    // Large "сум" amounts use non-breaking spaces; scaleDown
                    // keeps the hero on one line instead of overflowing.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Money.format((d.totalCurrent * ring).round()),
                        maxLines: 1,
                        style: NebulaTypography.of(context).displayL.copyWith(
                              fontSize: NebulaTypography.of(context)
                                      .displayL
                                      .fontSize! *
                                  1.35,
                              color: tokens.primaryText,
                              shadows: isLight
                                  ? null
                                  : [
                                      Shadow(
                                        color: Colors.white.withValues(
                                            alpha: NebulaAlpha.strong +
                                                breathe * 0.20),
                                        blurRadius: 3,
                                      ),
                                      Shadow(
                                        color: NebulaColors.successMint
                                            .withValues(
                                                alpha: NebulaAlpha.strong +
                                                    breathe * 0.20),
                                        blurRadius: 14,
                                      ),
                                      Shadow(
                                        color: NebulaColors.successMint
                                            .withValues(
                                                alpha: NebulaAlpha.subtle +
                                                    breathe * 0.10),
                                        blurRadius: 32,
                                      ),
                                    ],
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'из ${Money.format(d.goalAmount)}',
                      style: NebulaTypography.of(context).bodyM.copyWith(
                            color: tokens.secondaryText,
                            letterSpacing: 0.2,
                          ),
                    ),
                    const SizedBox(height: 32),
                    RepaintBoundary(
                      child: SizedBox(
                        width: 300,
                        height: 300,
                        child: CustomPaint(
                          // Light: a glass bubble with liquid circulating
                          // inside — the fill level IS the progress.
                          // Dark: the signature ASCII glow ring.
                          painter: isLight
                              ? _LiquidBubblePainter(
                                  earnedFrac: earnedFrac * ring,
                                  pendingFrac: pendingFrac * ring,
                                  wave: _waveCtrl.value,
                                  success: tokens.success,
                                  warning: tokens.warning,
                                  ink: tokens.primaryText,
                                )
                              : _RingPainter(
                                  earnedFrac: earnedFrac * ring,
                                  pendingFrac: pendingFrac * ring,
                                  breathe: breathe,
                                ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  d.goalAmount > 0
                                      ? '${((d.totalCurrent / d.goalAmount) * 100).round()}%'
                                      : '—',
                                  style: NebulaTypography.of(context)
                                      .displayL
                                      .copyWith(
                                        fontSize: NebulaTypography.of(context)
                                                .displayL
                                                .fontSize! *
                                            1.15,
                                        color: tokens.primaryText,
                                        shadows: isLight
                                            ? null
                                            : [
                                                Shadow(
                                                  color: Colors.white
                                                      .withValues(
                                                          alpha: NebulaAlpha
                                                                  .strong +
                                                              breathe * 0.2),
                                                  blurRadius: 4,
                                                ),
                                                Shadow(
                                                  color: NebulaColors
                                                      .successMint
                                                      .withValues(
                                                          alpha: NebulaAlpha
                                                                  .medium +
                                                              breathe * 0.15),
                                                  blurRadius: 12,
                                                ),
                                              ],
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'выполнено',
                                  style: NebulaTypography.of(context)
                                      .labelS
                                      .copyWith(
                                        color: tokens.mutedText,
                                        letterSpacing: 0.3,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ), // RepaintBoundary
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: _LegendDot(
                            color: tokens.success,
                            label: 'Проведено',
                            value: _fmt(d.earnedAmount),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Flexible(
                          child: _LegendDot(
                            color: tokens.warning,
                            label: 'Пропуски',
                            value: _fmt(d.pendingAmount),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              0.0,
              0.65,
            ),
            const SizedBox(height: 16),

            // ── Lesson stats grid ───────────────────────────────────────────
            entered(
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Проведено',
                      value: '${d.lessonsDone}',
                      sublabel: 'уроков',
                      color: tokens.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.schedule_rounded,
                      label: 'Пропуски',
                      value: '${d.lessonsMissed}',
                      sublabel: 'ученик',
                      color: tokens.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.warning_amber_rounded,
                      label: 'Долг',
                      value: '${d.lessonsDebt}',
                      sublabel: 'педагог',
                      color: tokens.error,
                    ),
                  ),
                ],
              ),
              0.2,
              0.8,
            ),

            if (d.lessonsMakeupDone > 0) ...[
              const SizedBox(height: 10),
              entered(_MakeupBanner(count: d.lessonsMakeupDone), 0.3, 0.85),
            ],

            const SizedBox(height: 16),

            if (d.lessonsDebt > 0) ...[
              entered(_DebtBanner(count: d.lessonsDebt), 0.35, 0.9),
              const SizedBox(height: 16),
            ],

            if (d.lessonsMissed > 0) ...[
              entered(_PendingBanner(amount: Money.format(d.pendingAmount)), 0.35, 0.9),
              const SizedBox(height: 16),
            ],

            // ── Breakdown card ──────────────────────────────────────────────
            entered(
              NebulaSurface(
                padding: const EdgeInsets.all(20),
                radiusRole: NebulaRadiusRole.panel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.account_balance_wallet_rounded,
                          color: tokens.primaryAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'РАЗБИВКА ВЫПЛАТ',
                        style: NebulaTypography.of(context).overline.copyWith(
                              color: tokens.primaryAccent,
                            ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    _PayRow(
                      label: 'Аванс (1–15)',
                      value: Money.format(d.advanceAmount),
                      color: tokens.primaryAccent,
                    ),
                    Divider(color: tokens.surfaceBorder, height: 24),
                    _PayRow(
                      label: 'Доплата (16–конец)',
                      value: Money.format(d.finalAmount),
                      color: tokens.secondaryAccent,
                    ),
                    Divider(color: tokens.surfaceBorder, height: 24),
                    _PayRow(
                      label: 'Итого к выплате',
                      value: Money.format(d.totalAmount),
                      color: tokens.success,
                      bold: true,
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Куплено уроков: ${d.totalSubscribed}  •  Цель: ${Money.format(d.goalAmount)}',
                        style: NebulaTypography.of(context).labelS.copyWith(
                              color: tokens.mutedText,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              0.45,
              1.0,
            ),
            const SizedBox(height: 16),

            // ── Rates config card ───────────────────────────────────────────
            ratesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => entered(
                _InlineErrorCard(
                  message: parseApiError(
                    e,
                    fallback: 'Не удалось загрузить ставки',
                  ),
                  onRetry: () => ref.invalidate(ratesProvider),
                ),
                0.55,
                1.0,
              ),
              data: (rates) =>
                  entered(_RatesCard(rates: rates, fmt: _fmt), 0.55, 1.0),
            ),

            const SizedBox(height: 24),

            // ── Reset month button ──────────────────────────────────────────
            entered(
              Center(
                child: NebulaTextButton(
                  label: 'Сбросить данные месяца',
                  icon: Icons.delete_sweep_rounded,
                  color: tokens.error,
                  filled: true,
                  compact: true,
                  onPressed: _resetMonth,
                ),
              ),
              0.65,
              1.0,
            ),
          ],
        );
      },
    );
  }
}
