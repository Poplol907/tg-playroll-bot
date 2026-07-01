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
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/adaptive_modal.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_modal_surface.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/pulse_indicator.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../shared/widgets/jiggle_delete_wrapper.dart';
import '../../../../shared/widgets/app_chrome_metrics.dart';
import '../../../../shared/widgets/app_safe_layout.dart';
import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../shared/providers/bottom_bar_visibility_provider.dart';
import '../../../../shared/providers/data_refresh_provider.dart';
import '../providers/calendar_provider.dart';
import '../../data/calendar_repository.dart';
import '../widgets/constellation_calendar.dart';
import '../widgets/lesson_modal.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../admin/presentation/providers/view_as_teacher_provider.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../features/students/data/students_repository.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/nebula_segmented_control.dart';
import '../../../rooms/presentation/providers/room_board_providers.dart';
import '../../../rooms/presentation/screens/room_board_screen.dart';
import '../../../rooms/presentation/widgets/rooms_today_card.dart';
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
    final month = ref.watch(selectedMonthProvider);
    final monthYear = DateFormat('yyyy-MM').format(month);
    final viewAs = ref.watch(viewAsTeacherProvider);
    final lessonsQuery = (monthYear: monthYear, teacherId: viewAs?.id);
    final lessonsAsync = ref.watch(lessonsProvider(lessonsQuery));
    final user = ref.watch(currentUserProvider);
    final scope = ref.watch(calendarScopeProvider);

    // ── Haptic vibration scaled by unfilled lesson count ──
    ref.listen<AsyncValue<List<LessonModel>>>(
      lessonsProvider(lessonsQuery),
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

    final header = AppScreenHeader(
      title: user?.displayName ?? 'Педагог',
      subtitle: 'Расписание уроков',
    );

    Widget contentFor(List<LessonModel> lessons, {required bool desktop}) {
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

      if (desktop) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            children: [
              const RoomsTodayCard(),
              Expanded(
                child: NebulaSurface(
                  padding: const EdgeInsets.all(16),
                  radiusRole: NebulaRadiusRole.panel,
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

      return AppCustomScrollView(
        header: header,
        padding: AppSafeInsets.screen(
          context,
          left: 16,
          right: 16,
          bottom: 24,
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const RoomsTodayCard(),
                NebulaSurface(
                  padding: const EdgeInsets.all(16),
                  radiusRole: NebulaRadiusRole.panel,
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
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              // Clear the floating month island (the shell already consumed the
              // hardware top inset via SafeArea(top:true)).
              padding: const EdgeInsets.fromLTRB(
                16,
                AppChromeMetrics.routeContentTopReservation + 8,
                16,
                4,
              ),
              child: NebulaSegmentedControl(
                segments: const ['Ученики', 'Кабинеты'],
                selectedIndex: scope.index,
                onChanged: (i) =>
                    ref.read(calendarScopeProvider.notifier).state =
                        CalendarScope.values[i],
              ),
            ),
            Expanded(
              child: scope == CalendarScope.rooms
                  ? const RoomBoardScreen()
                  : AppPlatform.isDesktop
            ? Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.displayName ?? 'Педагог',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                    ),
                  ),
                  Expanded(
                    child: lessonsAsync.when(
                      skipLoadingOnRefresh: false,
                      loading: () => const Center(child: OrbitLoader()),
                      error: (e, _) => Center(
                        child: AppErrorCard(
                          message: parseApiError(
                            e,
                            fallback: 'Нет подключения',
                          ),
                          onRetry: () => invalidateMonthData(ref, monthYear),
                          isConnectionError: isConnectionError(e),
                        ),
                      ),
                      data: (lessons) => contentFor(lessons, desktop: true),
                    ),
                  ),
                ],
              )
            : lessonsAsync.when(
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
                          message: parseApiError(
                            e,
                            fallback: 'Нет подключения',
                          ),
                          onRetry: () => invalidateMonthData(ref, monthYear),
                          isConnectionError: isConnectionError(e),
                        ),
                      ),
                    ),
                  ],
                ),
                data: (lessons) => contentFor(lessons, desktop: false),
              ),
            ),
          ],
        ),
      ),
    );
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
    runWithBottomBarHidden<void>(context, () {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        enableDrag: false,
        builder: (_) => _DayLessonsSheet(date: date, lessons: lessons),
      );
    });
  }
}
