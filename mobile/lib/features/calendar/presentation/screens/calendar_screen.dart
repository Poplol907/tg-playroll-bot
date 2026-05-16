import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/adaptive_modal.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/pulse_indicator.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../shared/widgets/jiggle_delete_wrapper.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/providers/data_refresh_provider.dart';
import '../providers/calendar_provider.dart';
import '../../data/calendar_repository.dart';
import '../widgets/constellation_calendar.dart';
import '../widgets/lesson_modal.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../features/students/data/students_repository.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/models/lesson.dart';
import '../../../../shared/models/student.dart';

part '../widgets/calendar_month_stats.dart';
part '../widgets/day_lessons_sheet.dart';
part '../widgets/add_lesson_sheet.dart';
part '../widgets/day_lessons_dialog.dart';

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final month = ref.watch(selectedMonthProvider);
    final monthYear = DateFormat('yyyy-MM').format(month);
    final lessonsAsync = ref.watch(lessonsProvider(monthYear));
    final user = ref.watch(currentUserProvider);

    // ── Haptic vibration scaled by unfilled lesson count ──
    ref.listen<AsyncValue<List<LessonModel>>>(
      lessonsProvider(monthYear),
      (_, next) {
        next.whenData((lessons) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          int unfilledCount = 0;
          for (final lesson in lessons) {
            final scheduled = lesson.scheduledDate;
            final dayDate =
                DateTime(scheduled.year, scheduled.month, scheduled.day);
            if (dayDate.isBefore(today) && lesson.status == 'scheduled') {
              unfilledCount++;
            }
          }
          if (unfilledCount == 0) return;
          if (unfilledCount <= 2) {
            HapticFeedback.lightImpact();
          } else if (unfilledCount <= 5) {
            HapticFeedback.mediumImpact();
          } else {
            HapticFeedback.heavyImpact();
            Future.delayed(
              const Duration(milliseconds: 150),
              HapticFeedback.heavyImpact,
            );
          }
        });
      },
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── App bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Педагог',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: tokens.primaryText,
                        ),
                      ),
                      Text(
                        'Расписание уроков',
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Logout button
                  GestureDetector(
                    onTap: () => _confirmLogout(context, ref),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isLight
                            ? const Color(0xFFE8EDF8)
                            : NebulaColors.nebulaSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: tokens.surfaceBorder),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: tokens.mutedText,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Calendar ──
            Expanded(
              child: lessonsAsync.when(
                loading: () => const Center(child: OrbitLoader()),
                error: (e, _) => Center(
                  child: AppErrorCard(
                    message: parseApiError(e, fallback: 'Нет подключения'),
                    onRetry: () => invalidateMonthData(ref, monthYear),
                    isConnectionError: isConnectionError(e),
                  ),
                ),
                data: (lessons) {
                  // Shared tap handler
                  void onDayTap(DateTime date) {
                    ref.read(selectedDayProvider.notifier).state = date;
                    final dayLessons = lessons
                        .where((l) =>
                            l.scheduledDate.year == date.year &&
                            l.scheduledDate.month == date.month &&
                            l.scheduledDate.day == date.day)
                        .toList();
                    _showDayLessons(context, date, dayLessons);
                  }

                  if (AppPlatform.isDesktop) {
                    // Desktop: calendar fills available height — no scroll needed
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        children: [
                          Expanded(
                            child: NebulaSurface(
                              padding: const EdgeInsets.all(16),
                              borderRadius: NebulaTokens.radiusLG,
                              child: ConstellationCalendar(
                                month: month,
                                lessons: lessons,
                                onDayTap: onDayTap,
                                enableAmbientMotion: true,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _MonthStats(lessons: lessons),
                        ],
                      ),
                    );
                  }

                  // Mobile: aspect-ratio square, scrollable if content overflows
                  return AppScrollView(
                    includeKeyboardInset: false,
                    padding: AppSafeInsets.screen(
                      context,
                      left: 16,
                      top: 0,
                      right: 16,
                      bottom: 24,
                    ),
                    child: Column(
                      children: [
                        NebulaSurface(
                          padding: const EdgeInsets.all(16),
                          borderRadius: NebulaTokens.radiusLG,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: ConstellationCalendar(
                              month: month,
                              lessons: lessons,
                              onDayTap: onDayTap,
                              enableAmbientMotion: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _MonthStats(lessons: lessons),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    NebulaDialog.confirm(
      context,
      title: 'Выйти из аккаунта?',
      message: 'Текущая сессия будет завершена на этом устройстве.',
      confirmLabel: 'Выйти',
      destructive: true,
      icon: Icons.logout_rounded,
    ).then((confirmed) {
      if (confirmed) ref.read(authProvider.notifier).logout();
    });
  }

  void _showDayLessons(
      BuildContext context, DateTime date, List<dynamic> lessons) {
    if (AppPlatform.isDesktop) {
      AdaptiveModal.show(
        context,
        builder: (_) => _DayLessonsDialog(date: date, lessons: lessons),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      builder: (_) => _DayLessonsSheet(date: date, lessons: lessons),
    );
  }
}
