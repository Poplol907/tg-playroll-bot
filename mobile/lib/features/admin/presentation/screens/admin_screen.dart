import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_modal_surface.dart';
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
import '../../data/admin_repository.dart';
import '../providers/view_as_teacher_provider.dart';
import '../widgets/create_user_sheet.dart';
import '../widgets/set_password_sheet.dart';

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
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(studioStatsProvider);
    final usersAsync = ref.watch(orgUsersProvider);
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
      trailing: IconButton(
        tooltip: 'Добавить пользователя',
        onPressed: addUser,
        icon: const Icon(
          Icons.person_add_outlined,
          color: NebulaColors.stellarBlue,
        ),
      ),
    );

    final teachers = _TeachersList(
      statsAsync: statsAsync,
      usersAsync: usersAsync,
      query: _query,
      onChanged: () {
        ref.invalidate(orgUsersProvider);
        ref.invalidate(studioStatsProvider);
      },
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: _SearchField(
                      onChanged: (s) => setState(() => _query = s.trim()),
                    ),
                  ),
                  Expanded(child: teachers),
                ],
              )
            : AppCustomScrollView(
                header: header,
                includeKeyboardInset: true,
                slivers: [
                  SliverToBoxAdapter(
                    child: _StudioStatsCard(statsAsync: statsAsync),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: _SearchField(
                      onChanged: (s) => setState(() => _query = s.trim()),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  _TeachersList(
                    statsAsync: statsAsync,
                    usersAsync: usersAsync,
                    query: _query,
                    onChanged: teachers.onChanged,
                    sliver: true,
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Studio stats card
// ─────────────────────────────────────────────

class _StudioStatsCard extends StatelessWidget {
  final AsyncValue<StudioStats> statsAsync;

  const _StudioStatsCard({required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return statsAsync.when(
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
                    value: _formatMoney(s.totalAmount),
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

  String _formatMoney(int amount) {
    final formatter = NumberFormat.decimalPattern('ru');
    return '${formatter.format(amount)} ₽';
  }
}

// ─────────────────────────────────────────────
//  Search field
// ─────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final ValueChanged<String> onChanged;

  const _SearchField({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Container(
      decoration: BoxDecoration(
        color: NebulaColors.nebulaSurface,
        borderRadius: NebulaRadii.cardBorder,
        border: Border.all(color: NebulaColors.surfaceBorder),
      ),
      child: TextField(
        onChanged: onChanged,
        style: NebulaTypography.of(context)
            .bodyM
            .copyWith(color: tokens.primaryText),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          hintText: 'Поиск по имени или логину...',
          hintStyle: NebulaTypography.of(context)
              .bodyM
              .copyWith(color: tokens.mutedText),
          prefixIcon:
              Icon(Icons.search_rounded, color: tokens.mutedText, size: 18),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Teachers list
//  Объединяет данные из orgUsersProvider (user info) и studioStatsProvider (stats)
// ─────────────────────────────────────────────

class _TeachersList extends ConsumerWidget {
  final AsyncValue<StudioStats> statsAsync;
  final AsyncValue<List<OrgUser>> usersAsync;
  final String query;
  final VoidCallback onChanged;
  final bool sliver;

  const _TeachersList({
    required this.statsAsync,
    required this.usersAsync,
    required this.query,
    required this.onChanged,
    this.sliver = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ждём оба провайдера
    if (usersAsync.isLoading) {
      const child = Center(child: OrbitLoader());
      return sliver
          ? const SliverFillRemaining(hasScrollBody: false, child: child)
          : child;
    }
    if (usersAsync.hasError) {
      final child = Center(
        child: AppErrorCard(
          message: parseApiError(usersAsync.error!,
              fallback: 'Ошибка загрузки списка'),
          onRetry: () {
            ref.invalidate(orgUsersProvider);
            ref.invalidate(studioStatsProvider);
          },
          isConnectionError: isConnectionError(usersAsync.error!),
        ),
      );
      return sliver
          ? SliverFillRemaining(hasScrollBody: false, child: child)
          : child;
    }

    final users = usersAsync.value ?? [];
    final teachers = users.where((u) => !u.isAdmin).toList();

    // Фильтр по поиску (нечувствительный к регистру)
    final q = query.toLowerCase();
    final filtered = q.isEmpty
        ? teachers
        : teachers.where((t) {
            final name = (t.teacherName ?? '').toLowerCase();
            final login = t.login.toLowerCase();
            return name.contains(q) || login.contains(q);
          }).toList();

    // Маппинг user → stats
    final statsByTeacher = <int, TeacherStats>{};
    statsAsync.whenData((s) {
      for (final t in s.teachers) {
        statsByTeacher[t.teacherId] = t;
      }
    });

    if (filtered.isEmpty) {
      final child = AppEmptyState(
        message: q.isEmpty ? 'Нет педагогов' : 'Никого не нашли',
        subtitle: q.isEmpty
            ? 'Нажмите + чтобы добавить педагога'
            : 'Попробуй другой запрос',
        icon: Icons.school_outlined,
      );
      return sliver
          ? SliverFillRemaining(hasScrollBody: false, child: child)
          : child;
    }

    if (sliver) {
      return SliverList.builder(
        itemCount: filtered.length,
        itemBuilder: (context, i) => _TeacherTile(
          user: filtered[i],
          stats: statsByTeacher[filtered[i].id],
          onUpdated: onChanged,
        ),
      );
    }

    return AppListView.builder(
      includeKeyboardInset: true,
      padding: AppSafeInsets.list(
        context,
        top: 4,
        bottom: 24,
        includeKeyboard: true,
      ),
      itemCount: filtered.length,
      itemBuilder: (context, i) => _TeacherTile(
        user: filtered[i],
        stats: statsByTeacher[filtered[i].id],
        onUpdated: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Teacher tile
// ─────────────────────────────────────────────

class _TeacherTile extends ConsumerWidget {
  final OrgUser user;
  final TeacherStats? stats;
  final VoidCallback onUpdated;

  const _TeacherTile({
    required this.user,
    required this.stats,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsDone = stats?.lessonsDone ?? 0;
    final totalAmount = stats?.totalAmount ?? 0;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    final trailing = user.hasPassword
        ? Icon(Icons.chevron_right_rounded, color: tokens.mutedText, size: 20)
        : const StatusBadge(
            label: 'НЕТ ПАРОЛЯ',
            icon: Icons.lock_open_rounded,
            intent: SemanticIntent.warning,
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: NebulaSurface(
        padding: EdgeInsets.zero,
        child: IconCallout(
          icon: Icons.school_outlined,
          title: user.displayName,
          subtitle:
              '${user.login} · $lessonsDone уроков · ${_formatMoney(totalAmount)}',
          intent: SemanticIntent.info,
          onTap: () => _openProfile(context, ref),
          trailing: trailing,
        ),
      ),
    );
  }

  String _formatMoney(int amount) {
    if (amount == 0) return '0 ₽';
    final formatter = NumberFormat.decimalPattern('ru');
    return '${formatter.format(amount)} ₽';
  }

  void _openProfile(BuildContext context, WidgetRef ref) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: NebulaAlpha.strong),
      builder: (_) => _TeacherProfileDialog(
        user: user,
        stats: stats,
        onUpdated: onUpdated,
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Teacher profile dialog
// ─────────────────────────────────────────────

class _TeacherProfileDialog extends ConsumerWidget {
  final OrgUser user;
  final TeacherStats? stats;
  final VoidCallback onUpdated;

  const _TeacherProfileDialog({
    required this.user,
    required this.stats,
    required this.onUpdated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = stats;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: NebulaModalSurface(
        containerKey: const ValueKey('teacher-profile-modal-surface'),
        chrome: NebulaModalChrome.dialog,
        constraints: const BoxConstraints(maxWidth: 460),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: NebulaColors.stellarBlue
                          .withValues(alpha: NebulaAlpha.surface),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: NebulaColors.stellarBlue
                              .withValues(alpha: NebulaAlpha.accent)),
                    ),
                    child: const Icon(Icons.school_outlined,
                        color: NebulaColors.stellarBlue, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.displayName,
                          style:
                              type.titleL.copyWith(color: tokens.primaryText),
                        ),
                        Text(
                          '@${user.login}',
                          style:
                              type.labelM.copyWith(color: tokens.secondaryText),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded,
                        color: tokens.mutedText, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Stats island — grouped so the numbers read as one block ──
              NebulaSurface(
                dense: true,
                radiusRole: NebulaRadiusRole.card,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'СТАТИСТИКА МЕСЯЦА',
                      style: type.overline.copyWith(color: tokens.mutedText),
                    ),
                    const SizedBox(height: 8),
                    _DialogStatRow(
                      icon: Icons.check_circle_outline_rounded,
                      label: 'Проведено',
                      value: '${s?.lessonsDone ?? 0}',
                      color: tokens.success,
                    ),
                    _DialogStatRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Пропусков',
                      value: '${s?.lessonsMissed ?? 0}',
                      color: tokens.error,
                    ),
                    _DialogStatRow(
                      icon: Icons.repeat_rounded,
                      label: 'Отработок',
                      value: '${s?.lessonsCancelledMakeup ?? 0}',
                      color: tokens.focusAccent,
                    ),
                    _DialogStatRow(
                      icon: Icons.cancel_outlined,
                      label: 'Долгов педагога',
                      value: '${s?.lessonsDebt ?? 0}',
                      color: tokens.warning,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Payout island — the headline number gets its own surface ──
              NebulaSurface(
                dense: true,
                radiusRole: NebulaRadiusRole.card,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                accent: tokens.success,
                child: Row(
                  children: [
                    Icon(Icons.payments_outlined,
                        color: tokens.success, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'К выплате',
                        style: type.bodyM.copyWith(color: tokens.secondaryText),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatMoney(s?.totalAmount ?? 0),
                          maxLines: 1,
                          style: type.titleM.copyWith(
                            color: tokens.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── View as teacher (главное действие) ──
              SizedBox(
                width: double.infinity,
                child: NebulaTextButton(
                  label: 'Открыть как педагог',
                  icon: Icons.visibility_outlined,
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(viewAsTeacherProvider.notifier).state =
                        ViewAsTeacher(
                      id: user.id,
                      displayName: user.displayName,
                    );
                    // Сбрасываем кэши: пользователь сменился — данные стали другими.
                    ref.invalidate(studioStatsProvider);
                    invalidateMonthData(ref, ref.read(globalMonthYearProvider));
                    context.go('/calendar');
                  },
                ),
              ),

              const SizedBox(height: 10),

              // ── Secondary actions ──
              Row(
                children: [
                  Expanded(
                    child: NebulaTextButton(
                      label: 'Сменить пароль',
                      icon: Icons.lock_outline_rounded,
                      onPressed: () async {
                        Navigator.pop(context);
                        final ok = await SetPasswordSheet.show(context, user);
                        if (ok) onUpdated();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NebulaTextButton(
                      label: 'Отключить',
                      icon: Icons.archive_outlined,
                      onPressed: () async {
                        Navigator.pop(context);
                        await _confirmAndDisable(context, ref);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── Destructive: permanent delete ──
              SizedBox(
                width: double.infinity,
                child: NebulaTextButton(
                  label: 'Удалить навсегда',
                  icon: Icons.delete_forever_outlined,
                  color: tokens.error,
                  onPressed: () async {
                    Navigator.pop(context);
                    await _confirmAndDelete(context, ref);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMoney(int amount) {
    final formatter = NumberFormat.decimalPattern('ru');
    return '${formatter.format(amount)} ₽';
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

class _DialogStatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _DialogStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.bodyS.copyWith(color: tokens.secondaryText),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                value,
                maxLines: 1,
                style: type.bodyM.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
