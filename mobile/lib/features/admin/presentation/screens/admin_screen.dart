import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/app_background_host.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/nebula_text_button.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../shared/providers/data_refresh_provider.dart';
import '../../../../shared/providers/month_provider.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../rooms/presentation/widgets/rooms_strip.dart';
import '../../data/admin_repository.dart';
import '../../data/payouts_repository.dart';
import '../../data/rates_repository.dart';
import '../payout_summary.dart';
import '../providers/view_as_teacher_provider.dart';
import '../widgets/add_payout_sheet.dart';
import '../widgets/create_user_sheet.dart';
import '../widgets/set_password_sheet.dart';
import '../widgets/set_rate_sheet.dart';

// ─────────────────────────────────────────────
//  AdminScreen — главный экран администратора
//  Показывает: статистику студии за месяц + список педагогов
//  Клик на педагога → детальный профиль с возможностью управления
// ─────────────────────────────────────────────

class AdminScreen extends ConsumerStatefulWidget {
  const AdminScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      SpacePageRoute(builder: (_) => const AdminScreen()),
    );
  }

  @override
  ConsumerState<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends ConsumerState<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(studioStatsProvider);
    final canPop = Navigator.of(context).canPop();
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    Future<void> addUser() async {
      HapticFeedback.lightImpact();
      final ok = await CreateUserSheet.show(context);
      if (ok) {
        ref.invalidate(orgUsersProvider);
        ref.invalidate(studioStatsProvider);
      }
    }

    Future<void> exportPayouts() async {
      HapticFeedback.lightImpact();
      final stats = statsAsync.valueOrNull;
      if (stats == null) {
        showNebulaSnackBar(
          context,
          title: 'Статистика ещё загружается',
          tone: NebulaSnackTone.info,
        );
        return;
      }
      await SharePlus.instance.share(
        ShareParams(text: buildPayoutSummary(stats)),
      );
    }

    final header = AppScreenHeader(
      title: 'Студия',
      subtitle: 'Обзор и педагоги',
      leading: canPop
          ? IconButton(
              tooltip: 'Назад',
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_rounded, color: tokens.mutedText),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Экспорт выплат',
            onPressed: exportPayouts,
            icon: Icon(Icons.ios_share_rounded, color: tokens.mutedText),
          ),
          IconButton(
            tooltip: 'Добавить пользователя',
            onPressed: addUser,
            icon: const Icon(
              Icons.person_add_outlined,
              color: NebulaColors.stellarBlue,
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: AppPlatform.isDesktop
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: header,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _StudioStatsCard(statsAsync: statsAsync),
                  ),
                  const _RoomsSection(),
                ],
              )
            : AppCustomScrollView(
                header: header,
                includeKeyboardInset: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: _StudioStatsCard(statsAsync: statsAsync),
                  ),
                  const SliverToBoxAdapter(child: _RoomsSection()),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Studio stats card
// ─────────────────────────────────────────────

class _RoomsSection extends StatelessWidget {
  const _RoomsSection();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text('Кабинеты',
              style: type.titleS.copyWith(color: tokens.primaryText)),
        ),
        const RoomsStrip(),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _StudioStatsCard extends StatelessWidget {
  final AsyncValue<StudioStats> statsAsync;

  const _StudioStatsCard({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return statsAsync.when(
      skipLoadingOnRefresh: false,
      loading: () => const NebulaSurface(
        padding: EdgeInsets.symmetric(vertical: 28),
        radiusRole: NebulaRadiusRole.panel,
        child: Center(child: OrbitLoader()),
      ),
      error: (e, _) => NebulaSurface(
        padding: const EdgeInsets.all(16),
        radiusRole: NebulaRadiusRole.panel,
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: NebulaColors.warningAmber, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                parseApiError(e, fallback: 'Не удалось загрузить статистику'),
                style: type.labelM.copyWith(color: tokens.secondaryText),
              ),
            ),
          ],
        ),
      ),
      data: (s) => NebulaSurface(
        padding: const EdgeInsets.all(16),
        radiusRole: NebulaRadiusRole.panel,
        accent: NebulaColors.stellarBlue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'СТАТИСТИКА СТУДИИ',
              style: type.overline.copyWith(color: tokens.mutedText),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MetricStat(
                    label: 'Заработок',
                    value: Money.format(s.totalAmount),
                    intent: SemanticIntent.success,
                  ),
                ),
                Expanded(
                  child: MetricStat(
                    label: 'Уроков',
                    value: '${s.totalLessonsDone}',
                    intent: SemanticIntent.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MetricStat(
                    label: 'Учеников',
                    value: '${s.activeStudents}',
                    intent: SemanticIntent.info,
                  ),
                ),
                Expanded(
                  child: MetricStat(
                    label: 'Педагогов',
                    value: '${s.activeTeachers}',
                    intent: SemanticIntent.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Teacher profile entry (test seam + single push point)
// ─────────────────────────────────────────────

/// Opens the full-screen teacher profile. Public so tests can drive the real
/// navigation without reaching into private tile internals.
abstract final class TeacherProfileEntry {
  static void open(
    BuildContext context, {
    required OrgUser user,
    required TeacherStats? stats,
    required VoidCallback onUpdated,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      SlideUpPageRoute(
        builder: (_) => _TeacherProfileScreen(
          user: user,
          stats: stats,
          onUpdated: onUpdated,
        ),
      ),
    );
  }

  /// Test-only convenience: a button that opens the profile with a no-op
  /// onUpdated. Labelled "open-profile".
  @visibleForTesting
  static Widget button({
    required BuildContext context,
    required OrgUser user,
    required TeacherStats? stats,
  }) {
    return ElevatedButton(
      onPressed: () =>
          open(context, user: user, stats: stats, onUpdated: () {}),
      child: const Text('open-profile'),
    );
  }
}

// ─────────────────────────────────────────────
//  Teacher profile screen
// ─────────────────────────────────────────────

class _TeacherProfileScreen extends ConsumerWidget {
  final OrgUser user;
  final TeacherStats? stats;
  final VoidCallback onUpdated;

  const _TeacherProfileScreen({
    required this.user,
    required this.stats,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackgroundHost(
        interactive: false,
        darkBackground: AppDarkBackground.asciiWater,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: AppScreenHeader(
                  title: user.displayName,
                  subtitle: '@${user.login}',
                  leading: IconButton(
                    tooltip: 'Назад',
                    onPressed: () => Navigator.pop(context),
                    icon:
                        Icon(Icons.arrow_back_rounded, color: tokens.mutedText),
                  ),
                ),
              ),
              Expanded(
                child: ScrollEdgeFade(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(NebulaTokens.sp16,
                        NebulaTokens.sp8, NebulaTokens.sp16, NebulaTokens.sp32),
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Имя уже в шапке экрана — дублирующей identity-
                        // карточки больше нет, профиль начинается со статы.

                        // ── Combined stats tile: месяц · выплаты · ставка ──
                        _TeacherStatsPager(user: user, stats: s),
                        const SizedBox(height: NebulaTokens.sp20),

                        // ── Actions: одна лаконичная карточка-список ──
                        NebulaSurface(
                          dense: true,
                          radiusRole: NebulaRadiusRole.card,
                          padding: const EdgeInsets.symmetric(
                              horizontal: NebulaTokens.sp8,
                              vertical: NebulaTokens.sp4),
                          child: Column(
                            children: [
                              ActionRow(
                                icon: Icons.visibility_outlined,
                                label: 'Открыть как педагог',
                                intent: SemanticIntent.primary,
                                onTap: () {
                                  final router = GoRouter.of(context);
                                  ref
                                      .read(viewAsTeacherProvider.notifier)
                                      .state = ViewAsTeacher(
                                    id: user.id,
                                    displayName: user.displayName,
                                  );
                                  ref.invalidate(studioStatsProvider);
                                  invalidateMonthData(
                                      ref, ref.read(globalMonthYearProvider));
                                  Navigator.pop(context);
                                  router.go('/calendar');
                                },
                              ),
                              Divider(
                                  height: 1,
                                  indent: 56,
                                  color: tokens.surfaceBorder),
                              ActionRow(
                                icon: Icons.lock_outline_rounded,
                                label: 'Сменить пароль',
                                intent: SemanticIntent.info,
                                onTap: () async {
                                  final ok = await SetPasswordSheet.show(
                                      context, user);
                                  if (ok) onUpdated();
                                },
                              ),
                              Divider(
                                  height: 1,
                                  indent: 56,
                                  color: tokens.surfaceBorder),
                              ActionRow(
                                icon: Icons.archive_outlined,
                                label: 'Отключить',
                                intent: SemanticIntent.warning,
                                onTap: () => _confirmAndDisable(context, ref),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: NebulaTokens.sp32),

                        // ── Destructive: тихая текстовая кнопка в самом низу ──
                        Center(
                          child: NebulaTextButton(
                            label: 'Удалить навсегда',
                            icon: Icons.delete_forever_outlined,
                            color: tokens.error,
                            compact: true,
                            onPressed: () => _confirmAndDelete(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndDisable(BuildContext context, WidgetRef ref) async {
    final confirm = await NebulaDialog.confirm(
      context,
      title: 'Отключить педагога?',
      message:
          '${user.displayName} больше не сможет войти и исчезнет из списка, но все уроки, ставки и история выплат сохранятся в базе.',
      confirmLabel: 'Отключить',
      cancelLabel: 'Отмена',
    );
    if (!confirm) return;

    try {
      await ref.read(adminRepositoryProvider).disableUser(user.id);
      HapticFeedback.mediumImpact();
      onUpdated();
      if (context.mounted) {
        showNebulaSnackBar(
          context,
          title: 'Отключено',
          message: '${user.displayName} архивирован, история сохранена',
          tone: NebulaSnackTone.success,
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      if (context.mounted) {
        showNebulaSnackBar(
          context,
          title: 'Не удалось отключить',
          message: parseApiError(e),
          tone: NebulaSnackTone.error,
        );
      }
    }
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await NebulaDialog.confirm(
      context,
      title: 'Удалить навсегда?',
      message:
          'Педагог ${user.displayName} и ВСЕ его данные — уроки, ставки, подписки — будут удалены безвозвратно. Чтобы сохранить историю, используй «Отключить».',
      confirmLabel: 'Удалить',
      cancelLabel: 'Отмена',
      destructive: true,
    );
    if (!confirm) return;

    try {
      await ref.read(adminRepositoryProvider).deleteUser(user.id);
      HapticFeedback.mediumImpact();
      onUpdated();
      if (context.mounted) {
        showNebulaSnackBar(
          context,
          title: 'Удалено',
          message: '${user.displayName} и все данные удалены',
          tone: NebulaSnackTone.success,
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      if (context.mounted) {
        showNebulaSnackBar(
          context,
          title: 'Не удалось удалить',
          message: parseApiError(e),
          tone: NebulaSnackTone.error,
        );
      }
    }
  }
}

// ─────────────────────────────────────────────
//  Teacher stats pager — вся стата в одном тайле:
//  месяц · выплаты · ставка, свайп + dot-индикатор
// ─────────────────────────────────────────────

class _TeacherStatsPager extends ConsumerStatefulWidget {
  final OrgUser user;
  final TeacherStats? stats;

  const _TeacherStatsPager({required this.user, required this.stats});

  @override
  ConsumerState<_TeacherStatsPager> createState() => _TeacherStatsPagerState();
}

class _TeacherStatsPagerState extends ConsumerState<_TeacherStatsPager> {
  static const int _pageCount = 3;

  /// Fixed page height keeps the tile stable while pages swap; sized to the
  /// tallest page (payouts: ring + rows + inline action).
  static const double _pageHeight = 200;

  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index == _page) return;
    HapticFeedback.selectionClick();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: NebulaTokens.tabTransition,
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    // Accessibility text sizes need taller pages or rows start clipping.
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final pageHeight = _pageHeight * textScale.clamp(1.0, 1.6).toDouble();

    return NebulaSurface(
      key: const ValueKey('teacher-stats-pager'),
      dense: true,
      radiusRole: NebulaRadiusRole.card,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: pageHeight,
            child: PageView(
              controller: _controller,
              onPageChanged: (index) => setState(() => _page = index),
              children: [
                _MonthStatsPage(stats: widget.stats),
                _PayoutPage(user: widget.user, stats: widget.stats),
                _RatePage(user: widget.user),
              ],
            ),
          ),
          const SizedBox(height: NebulaTokens.sp4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pageCount; i++)
                GestureDetector(
                  key: ValueKey('stats-pager-dot-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _goTo(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NebulaTokens.sp4,
                      vertical: NebulaTokens.sp8,
                    ),
                    child: AnimatedContainer(
                      duration: NebulaTokens.feedback,
                      curve: Curves.easeOut,
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: NebulaRadii.pillBorder,
                        color: i == _page
                            ? tokens.focusAccent
                            : tokens.mutedText
                                .withValues(alpha: NebulaAlpha.accent),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthStatsPage extends StatelessWidget {
  final TeacherStats? stats;

  const _MonthStatsPage({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final s = stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _CategoryTag('СТАТИСТИКА МЕСЯЦА')),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(children: [
                Expanded(
                    child: _BigStat(
                  label: 'Проведено',
                  value: '${s?.lessonsDone ?? 0}',
                  color: tokens.success,
                )),
                Expanded(
                    child: _BigStat(
                  label: 'Пропусков',
                  value: '${s?.lessonsMissed ?? 0}',
                  color: tokens.error,
                )),
              ]),
              Row(children: [
                Expanded(
                    child: _BigStat(
                  label: 'Отработок',
                  value: '${s?.lessonsCancelledMakeup ?? 0}',
                  color: tokens.focusAccent,
                )),
                Expanded(
                    child: _BigStat(
                  label: 'Долгов',
                  value: '${s?.lessonsDebt ?? 0}',
                  color: tokens.warning,
                )),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _PayoutPage extends ConsumerWidget {
  final OrgUser user;
  final TeacherStats? stats;

  const _PayoutPage({required this.user, required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final month = ref.watch(globalMonthYearProvider);
    final paidAsync =
        ref.watch(teacherPaidProvider((teacherId: user.id, monthYear: month)));
    final owed = stats?.totalAmount ?? 0;
    final paid = paidAsync.valueOrNull;
    final frac =
        owed <= 0 ? 0.0 : ((paid ?? 0) / owed).clamp(0.0, 1.0).toDouble();

    Future<void> markPayout() async {
      final suggested =
          paid == null ? owed : (owed - paid).clamp(0, owed).toInt();
      final ok = await AddPayoutSheet.show(context, user.id, month, suggested);
      if (ok) {
        ref.invalidate(
            teacherPaidProvider((teacherId: user.id, monthYear: month)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _CategoryTag('ВЫПЛАТЫ ЗА МЕСЯЦ')),
        const SizedBox(height: NebulaTokens.sp12),
        Expanded(
          child: Row(
            children: [
              // Кольцо прогресса — сколько от «к выплате» уже закрыто.
              SizedBox(
                width: 96,
                height: 96,
                child: CustomPaint(
                  painter: _PayoutRingPainter(
                    fraction: frac,
                    track: tokens.surfaceBorder,
                    fill: tokens.success,
                  ),
                  child: Center(
                    child: Text(
                      paid == null ? '…' : '${(frac * 100).round()}%',
                      style: type.titleM.copyWith(
                        color: tokens.primaryText,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: NebulaTokens.sp16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MiniPayoutRow(
                      label: 'К выплате',
                      value: Money.format(owed),
                      color: tokens.success,
                    ),
                    const SizedBox(height: NebulaTokens.sp8),
                    paidAsync.when(
                      skipLoadingOnRefresh: false,
                      data: (paidValue) => Column(
                        children: [
                          _MiniPayoutRow(
                            label: 'Выплачено',
                            value: Money.format(paidValue),
                            color: tokens.primaryText,
                          ),
                          const SizedBox(height: NebulaTokens.sp8),
                          _MiniPayoutRow(
                            label: 'Осталось',
                            value:
                                Money.format((owed - paidValue).clamp(0, owed)),
                            color: tokens.warning,
                          ),
                        ],
                      ),
                      loading: () => const Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: NebulaTokens.sp8),
                        child: OrbitLoader(size: 18),
                      ),
                      error: (_, __) => _MiniPayoutRow(
                        label: 'Выплачено',
                        value: '—',
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: NebulaTextButton(
            label: 'Отметить выплату',
            icon: Icons.add_circle_outline_rounded,
            compact: true,
            onPressed: markPayout,
          ),
        ),
      ],
    );
  }
}

class _RatePage extends ConsumerWidget {
  final OrgUser user;

  const _RatePage({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final rateAsync = ref.watch(teacherDefaultRateProvider(user.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: _CategoryTag('СТАВКА ЗА УРОК')),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                rateAsync.when(
                  skipLoadingOnRefresh: false,
                  data: (rate) => Text(
                    Money.format(rate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: type.displayM.copyWith(color: tokens.primaryText),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: NebulaTokens.sp8),
                    child: OrbitLoader(size: 18),
                  ),
                  error: (_, __) => Text('—',
                      style: type.displayM.copyWith(color: tokens.mutedText)),
                ),
                const SizedBox(height: NebulaTokens.sp4),
                Text('начисляется за каждый проведённый урок',
                    textAlign: TextAlign.center,
                    style: type.bodyS.copyWith(color: tokens.secondaryText)),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: NebulaTextButton(
            label: 'Изменить',
            compact: true,
            onPressed: () async {
              final currentRate = rateAsync.valueOrNull ?? 0;
              final ok = await SetRateSheet.show(context, user.id, currentRate);
              if (ok) {
                ref.invalidate(teacherDefaultRateProvider(user.id));
              }
            },
          ),
        ),
      ],
    );
  }
}

/// Подпись категории страницы — «пилюля» с тонкой границей, по центру тайла.
class _CategoryTag extends StatelessWidget {
  final String text;

  const _CategoryTag(this.text);

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NebulaTokens.sp12,
        vertical: NebulaTokens.sp4,
      ),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: NebulaRadii.pillBorder,
        border: Border.all(color: tokens.surfaceBorder),
      ),
      child: Text(text, style: type.overline.copyWith(color: tokens.mutedText)),
    );
  }
}

/// Крупная центрированная метрика месяца: значение сверху, подпись снизу.
class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BigStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: type.titleL.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: NebulaTokens.sp2),
          Text(label, style: type.labelM.copyWith(color: tokens.secondaryText)),
        ],
      ),
    );
  }
}

class _MiniPayoutRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniPayoutRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: type.bodyS.copyWith(color: tokens.secondaryText)),
        ),
        const SizedBox(width: NebulaTokens.sp8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: type.titleS.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Кольцо прогресса выплат: тонкий трек + скруглённая дуга с мягким гало.
class _PayoutRingPainter extends CustomPainter {
  final double fraction;
  final Color track;
  final Color fill;

  const _PayoutRingPainter({
    required this.fraction,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 6;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const stroke = 9.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, trackPaint);

    if (fraction <= 0) return;
    final sweep = math.pi * 2 * fraction;
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke + 6
      ..strokeCap = StrokeCap.round
      ..color = fill.withValues(alpha: NebulaAlpha.subtle)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, glowPaint);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fillPaint);
  }

  @override
  bool shouldRepaint(_PayoutRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.track != track ||
      oldDelegate.fill != fill;
}
