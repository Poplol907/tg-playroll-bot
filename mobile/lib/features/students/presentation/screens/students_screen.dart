import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_component_styles.dart';
import '../../../../core/theme/nebula_semantic.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/models/student.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/jiggle_delete_wrapper.dart';
import '../../../../shared/widgets/nebula_parallax_frame.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/primitives/primitives.dart';
import '../../data/students_repository.dart';
import '../widgets/student_detail_sheet.dart';
import '../widgets/add_student_modal.dart';

class StudentsScreen extends ConsumerWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — wrapped for subtle pointer parallax depth
            NebulaParallaxFrame(
              strength: 0.018,
              maxOffset: 4.0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Row(
                  children: [
                    Builder(builder: (ctx) {
                      final isLight =
                          Theme.of(ctx).brightness == Brightness.light;
                      final titleText = Text(
                        'Ученики',
                        style: NebulaTypography.of(ctx).displayL.copyWith(
                              color: isLight
                                  ? Colors.white
                                  : NebulaColors.softWhite,
                            ),
                      );
                      if (!isLight) return titleText;
                      return ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF1A2540), Color(0xFF0D1117)],
                        ).createShader(bounds),
                        child: titleText,
                      );
                    }),
                    const Spacer(),
                    studentsAsync.whenOrNull(
                          data: (students) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: tokens.primaryAccent
                                  .withValues(alpha: NebulaAlpha.surface),
                              borderRadius:
                                  BorderRadius.circular(NebulaTokens.radiusSM),
                              border: Border.all(
                                  color: tokens.primaryAccent
                                      .withValues(alpha: NebulaAlpha.accent)),
                            ),
                            child: Text(
                              '${students.length}',
                              style:
                                  NebulaTypography.of(context).bodyM.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: tokens.primaryAccent,
                                      ),
                            ),
                          ),
                        ) ??
                        const SizedBox.shrink(),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _openAddStudent(context, ref),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: tokens.primaryAccent
                              .withValues(alpha: NebulaAlpha.surface),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: tokens.primaryAccent
                                  .withValues(alpha: NebulaAlpha.medium)),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: tokens.primaryAccent,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ), // NebulaParallaxFrame
            // List
            Expanded(
              child: studentsAsync.when(
                loading: () => const Center(child: OrbitLoader()),
                error: (e, _) => Center(
                  child: AppErrorCard(
                    message: parseApiError(e, fallback: 'Ошибка загрузки'),
                    onRetry: () => ref.invalidate(studentsProvider),
                    isConnectionError: isConnectionError(e),
                  ),
                ),
                data: (students) => students.isEmpty
                    ? const AppEmptyState(
                        message: 'Нет учеников',
                        subtitle: 'Нажмите + чтобы добавить первого ученика',
                        icon: Icons.people_outline_rounded,
                      )
                    : AppListView.builder(
                        padding: AppSafeInsets.list(
                          context,
                          top: 0,
                          bottom: 24,
                        ),
                        itemCount: students.length,
                        itemBuilder: (context, i) {
                          // Stagger ONLY the first viewport (cards 0..7) so a
                          // fresh open feels like a cascade. Anything beyond
                          // that — including cards revealed by fast scroll —
                          // appears instantly: no per-row delay can keep up
                          // with a flick, and any delay shows as a blank gap.
                          const stagger = 7;
                          final card =
                              _StudentCard(student: students[i], index: i);
                          if (i >= stagger) return card;
                          final delay = (i * 55).ms;
                          return card
                              .animate()
                              .fadeIn(
                                delay: delay,
                                duration: 240.ms,
                                curve: Curves.easeOut,
                              )
                              .slideY(
                                begin: 0.08,
                                end: 0,
                                delay: delay,
                                duration: 260.ms,
                                curve: Curves.easeOutCubic,
                              );
                        },
                      ),
              ),
            ),
          ],
        ),
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

  bool get _isNew {
    final diff = DateTime.now().difference(student.createdAt);
    return diff.inDays <= 7;
  }

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: JiggleDeleteWrapper(
        jiggleIndex: index,
        borderRadius: NebulaTokens.radiusMD,
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
          borderRadius: NebulaTokens.radiusMD,
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
                  if (_isNew)
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
                        if (_isNew) ...[
                          const SizedBox(width: 8),
                          // Ambient shimmer draws the eye to recently-added
                          // students. Suppressed under reduce-motion / in
                          // test bindings so it doesn't leave dangling
                          // periodic timers when the tree unmounts.
                          if (MediaQuery.of(context).disableAnimations)
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
