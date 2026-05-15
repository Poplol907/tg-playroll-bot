import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_surface_profile.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/nebula_text_button.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  if (canPop) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: NebulaColors.nebulaSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: NebulaColors.surfaceBorder),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: NebulaColors.dimText, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Студия',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: NebulaColors.softWhite,
                          ),
                        ),
                        Text(
                          'Обзор и педагоги',
                          style: TextStyle(
                            fontSize: 12,
                            color: NebulaColors.dimText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add user button
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final ok = await CreateUserSheet.show(context);
                      if (ok) {
                        ref.invalidate(orgUsersProvider);
                        ref.invalidate(studioStatsProvider);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: NebulaColors.stellarBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: NebulaColors.stellarBlue
                                .withValues(alpha: 0.4)),
                      ),
                      child: const Icon(Icons.person_add_outlined,
                          color: NebulaColors.stellarBlue, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // ── Studio stats card (compact) ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _StudioStatsCard(statsAsync: statsAsync),
            ),

            // ── Search field ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _SearchField(
                onChanged: (s) => setState(() => _query = s.trim()),
              ),
            ),

            // ── Teachers list ───────────────────────────────────────────
            Expanded(
              child: _TeachersList(
                statsAsync: statsAsync,
                usersAsync: usersAsync,
                query: _query,
                onChanged: () {
                  ref.invalidate(orgUsersProvider);
                  ref.invalidate(studioStatsProvider);
                },
              ),
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
    return statsAsync.when(
      loading: () => const NebulaSurface(
        padding: EdgeInsets.symmetric(vertical: 28),
        borderRadius: NebulaTokens.radiusLG,
        child: Center(child: OrbitLoader()),
      ),
      error: (e, _) => NebulaSurface(
        padding: const EdgeInsets.all(16),
        borderRadius: NebulaTokens.radiusLG,
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: NebulaColors.warningAmber, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                parseApiError(e, fallback: 'Не удалось загрузить статистику'),
                style: const TextStyle(
                    fontSize: 12, color: NebulaColors.mistWhite),
              ),
            ),
          ],
        ),
      ),
      data: (s) => NebulaSurface(
        padding: const EdgeInsets.all(16),
        borderRadius: NebulaTokens.radiusLG,
        accent: NebulaColors.stellarBlue,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'СТАТИСТИКА СТУДИИ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: NebulaColors.ghostText,
                letterSpacing: 0.8,
              ),
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
    return Container(
      decoration: BoxDecoration(
        color: NebulaColors.nebulaSurface,
        borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
        border: Border.all(color: NebulaColors.surfaceBorder),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: NebulaColors.softWhite),
        decoration: const InputDecoration(
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: InputBorder.none,
          hintText: 'Поиск по имени или логину...',
          hintStyle: TextStyle(fontSize: 14, color: NebulaColors.ghostText),
          prefixIcon:
              Icon(Icons.search_rounded, color: NebulaColors.dimText, size: 18),
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

  const _TeachersList({
    required this.statsAsync,
    required this.usersAsync,
    required this.query,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ждём оба провайдера
    if (usersAsync.isLoading) {
      return const Center(child: OrbitLoader());
    }
    if (usersAsync.hasError) {
      return Center(
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
      return AppEmptyState(
        message: q.isEmpty ? 'Нет педагогов' : 'Никого не нашли',
        subtitle: q.isEmpty
            ? 'Нажмите + чтобы добавить педагога'
            : 'Попробуй другой запрос',
        icon: Icons.school_outlined,
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
        borderRadius: NebulaTokens.radiusMD,
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
      barrierColor: Colors.black.withValues(alpha: 0.6),
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
    final modalSurface = NebulaSurfaceProfile.modal.resolve(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: modalSurface.fill,
          gradient: modalSurface.sheen,
          borderRadius: BorderRadius.circular(modalSurface.radius),
          border: Border.all(
            color: modalSurface.border,
            width: modalSurface.borderWidth,
          ),
          boxShadow: modalSurface.shadows,
        ),
        padding: const EdgeInsets.all(24),
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
                    color: NebulaColors.stellarBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: NebulaColors.stellarBlue.withValues(alpha: 0.3)),
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: tokens.primaryText,
                        ),
                      ),
                      Text(
                        '@${user.login}',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.secondaryText,
                        ),
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
            const SizedBox(height: 20),

            // ── Stats grid ──
            const Text(
              'СТАТИСТИКА МЕСЯЦА',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: NebulaColors.ghostText,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),
            _DialogStatRow(
              icon: Icons.check_circle_outline_rounded,
              label: 'Проведено',
              value: '${s?.lessonsDone ?? 0}',
              color: NebulaColors.successMint,
            ),
            _DialogStatRow(
              icon: Icons.warning_amber_rounded,
              label: 'Пропусков',
              value: '${s?.lessonsMissed ?? 0}',
              color: NebulaColors.errorRose,
            ),
            _DialogStatRow(
              icon: Icons.repeat_rounded,
              label: 'Отработок',
              value: '${s?.lessonsCancelledMakeup ?? 0}',
              color: NebulaColors.auroraCyan,
            ),
            _DialogStatRow(
              icon: Icons.cancel_outlined,
              label: 'Долгов педагога',
              value: '${s?.lessonsDebt ?? 0}',
              color: NebulaColors.warningAmber,
            ),
            const Divider(color: NebulaColors.surfaceBorder, height: 24),
            _DialogStatRow(
              icon: Icons.payments_outlined,
              label: 'К выплате',
              value: _formatMoney(s?.totalAmount ?? 0),
              color: NebulaColors.stellarBlue,
              valueBig: true,
            ),

            const SizedBox(height: 24),

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
                    label: 'Удалить',
                    icon: Icons.person_remove_outlined,
                    onPressed: () async {
                      Navigator.pop(context);
                      await _confirmAndDelete(context, ref);
                    },
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

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await NebulaDialog.confirm(
      context,
      title: 'Удалить педагога?',
      message:
          'Это действие нельзя отменить. Все связанные с ${user.displayName} данные останутся в базе, но войти под этим логином будет невозможно.',
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
          message: '${user.displayName} больше не имеет доступа',
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
  final bool valueBig;

  const _DialogStatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.valueBig = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: tokens.secondaryText,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: valueBig ? 18 : 14,
              fontWeight: valueBig ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
