import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_component_styles.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/models/student.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/jiggle_delete_wrapper.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../data/students_repository.dart';
import '../widgets/student_detail_sheet.dart';
import '../widgets/add_student_modal.dart';
import '../providers/seen_students_provider.dart';

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    final header = AppScreenHeader(
      title: 'Ученики',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (studentsAsync.valueOrNull != null)
            StatusBadge(
              label: '${studentsAsync.valueOrNull!.length}',
              intent: SemanticIntent.primary,
            ),
          IconButton(
            tooltip: 'Добавить ученика',
            onPressed: () => _openAddStudent(context, ref),
            icon: Icon(Icons.add_rounded, color: tokens.primaryAccent),
          ),
        ],
      ),
    );

    Widget buildCard(List<StudentModel> students, int i) {
      const stagger = 7;
      final card = _StudentCard(student: students[i], index: i);
      if (i >= stagger) return card;
      final delay = (i * 55).ms;
      return card
          .animate()
          .fadeIn(delay: delay, duration: 240.ms, curve: Curves.easeOut)
          .slideY(
            begin: 0.08,
            end: 0,
            delay: delay,
            duration: 260.ms,
            curve: Curves.easeOutCubic,
          );
    }

    Widget mobileBody() => studentsAsync.when(
          skipLoadingOnRefresh: false,
          loading: () => AppCustomScrollView(
            header: header,
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: OrbitLoader()),
              ),
            ],
          ),
          error: (e, _) => AppCustomScrollView(
            header: header,
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: AppErrorCard(
                    message: parseApiError(e, fallback: 'Ошибка загрузки'),
                    onRetry: () => ref.invalidate(studentsProvider),
                    isConnectionError: isConnectionError(e),
                  ),
                ),
              ),
            ],
          ),
          data: (students) => AppCustomScrollView(
            header: header,
            padding: AppSafeInsets.list(context, top: 20, bottom: 24),
            slivers: [
              if (students.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    message: 'Нет учеников',
                    subtitle: 'Нажмите + чтобы добавить первого ученика',
                    icon: Icons.people_outline_rounded,
                  ),
                )
              else
                SliverList.builder(
                  itemCount: students.length,
                  itemBuilder: (_, i) => buildCard(students, i),
                ),
            ],
          ),
        );

    Widget desktopBody() => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: header,
            ),
            Expanded(
              child: studentsAsync.when(
          skipLoadingOnRefresh: false,
                loading: () => const Center(child: OrbitLoader()),
                error: (e, _) => Center(
                  child: AppErrorCard(
                    message: parseApiError(e, fallback: 'Ошибка загрузки'),
                    onRetry: () => ref.invalidate(studentsProvider),
                    isConnectionError: isConnectionError(e),
                  ),
                ),
                data: (students) => AppListView.builder(
                  itemCount: students.length,
                  itemBuilder: (_, i) => buildCard(students, i),
                ),
              ),
            ),
          ],
        );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: AppPlatform.isDesktop ? desktopBody() : mobileBody(),
      ),
    );
  }

  Future<void> _openAddStudent(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final added = await AddStudentModal.show(context);
    if (added) {
      ref.invalidate(studentsProvider);
      if (context.mounted) {
        showNebulaSnackBar(
          context,
          title: 'Ученик добавлен',
          message: 'Новый ученик появится в списке',
          tone: NebulaSnackTone.success,
        );
      }
    }
  }
}

// ─────────────────────────────────────────────
//  Student card
// ─────────────────────────────────────────────

class _StudentCard extends ConsumerWidget {
  final StudentModel student;
  final int index;

  const _StudentCard({required this.student, this.index = 0});

  LinearGradient _avatarGradient() {
    final idx = student.id % 6;
    const gradients = [
      [NebulaColors.stellarBlue, NebulaColors.nebulaPurple],
      [NebulaColors.nebulaPurple, NebulaColors.errorRose],
      [NebulaColors.successMint, NebulaColors.stellarBlue],
      [NebulaColors.warningAmber, NebulaColors.errorRose],
      [NebulaColors.stellarBlue, NebulaColors.auroraCyan],
      [NebulaColors.nebulaPurple, NebulaColors.warningAmber],
    ];
    final colors = gradients[idx];
    return LinearGradient(
      colors: colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final nameColor = tokens.primaryText;
    final subColor = tokens.mutedText;
    final iconColor = tokens.mutedText.withValues(alpha: 0.72);
    final newBadgeBorder = isLight ? tokens.denseSurface : tokens.backgroundMid;
    // «Новый» гаснет, как только карточку открыли (см. seenStudentsProvider):
    // раньше бейдж висел все 7 дней независимо от того, заходил ли пользователь.
    final seen = ref.watch(seenStudentsProvider);
    final isNew = !seen.contains(student.id) &&
        DateTime.now().difference(student.createdAt).inDays <= 7;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: JiggleDeleteWrapper(
        jiggleIndex: index,
        borderRadius: NebulaRadii.card,
        onTap: () => StudentDetailSheet.show(context, student),
        onDeleteConfirmed: () async {
          final confirmed = await _confirmDelete(context);
          if (!confirmed) return;
          await ref.read(studentsRepositoryProvider).deleteStudent(student.id);
          ref.invalidate(studentsProvider);
          if (context.mounted) {
            HapticFeedback.mediumImpact();
            showNebulaSnackBar(
              context,
              title: '${student.fullName} удалён',
              tone: NebulaSnackTone.error,
            );
          }
        },
        child: NebulaSurface(
          // Same solid card mechanism as the salary / calendar cards —
          // opaque, readable, no excess transparency.
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: _avatarGradient(),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        student.initials,
                        style: NebulaTypography.of(context).titleM.copyWith(
                              color: Colors.black,
                            ),
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: tokens.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: newBadgeBorder, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.fullName,
                            style: NebulaTypography.of(context).titleM.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: nameColor,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isNew) ...[
                          const SizedBox(width: 8),
                          // Ambient shimmer draws the eye to recently-added
                          // students. Suppressed under reduce-motion / in
                          // test bindings (dangling periodic timers) / on
                          // lite-graphics Android (perpetual repaints).
                          if (MediaQuery.of(context).disableAnimations ||
                              AppPlatform.liteGraphics)
                            const StatusBadge(
                              label: 'НОВЫЙ',
                              intent: SemanticIntent.success,
                              styleOverride: BadgeStyle.compact,
                            )
                          else
                            const StatusBadge(
                              label: 'НОВЫЙ',
                              intent: SemanticIntent.success,
                              styleOverride: BadgeStyle.compact,
                            )
                                .animate(
                                  onPlay: (c) => c.repeat(),
                                )
                                .shimmer(
                                  duration: 1600.ms,
                                  delay: 1400.ms,
                                  color: Colors.white
                                      .withValues(alpha: NebulaAlpha.accent),
                                ),
                        ],
                        if (student.isForeign) ...[
                          const SizedBox(width: 6),
                          const StatusBadge(
                            label: 'EN',
                            intent: SemanticIntent.warning,
                            styleOverride: BadgeStyle.compact,
                          ),
                        ],
                      ],
                    ),
                    if (student.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        student.phone!,
                        style: NebulaTypography.of(context)
                            .labelM
                            .copyWith(color: subColor),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      student.status == 'active' || student.status == 'ACTIVE'
                          ? tokens.success
                          : tokens.mutedText,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: iconColor,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<bool> _confirmDelete(BuildContext context) async {
    return NebulaDialog.confirm(
      context,
      title: 'Удалить ученика?',
      message:
          'Все уроки и данные ученика будут удалены. Это действие нельзя отменить.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
  }
}
