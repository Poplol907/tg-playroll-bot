import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/platform/app_platform.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/models/lesson.dart';
import '../../../../shared/providers/bottom_bar_visibility_provider.dart';
import '../../../../shared/providers/data_refresh_provider.dart';
import '../../../../shared/widgets/adaptive_modal.dart';
import '../../../../shared/widgets/nebula_modal_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../shared/widgets/nebula_drum_picker.dart';
import '../providers/calendar_provider.dart';

class LessonModal extends ConsumerStatefulWidget {
  final LessonModel lesson;

  const LessonModal({super.key, required this.lesson});

  static Future<void> show(BuildContext context, LessonModel lesson) {
    if (AppPlatform.isDesktop) {
      return AdaptiveModal.show(
        context,
        builder: (_) => _LessonModalDesktop(lesson: lesson),
      );
    }
    return runWithBottomBarHidden(context, () {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
        enableDrag: false,
        barrierColor: Colors.black.withValues(alpha: NebulaAlpha.strong),
        builder: (_) => LessonModal(lesson: lesson),
      );
    });
  }

  @override
  ConsumerState<LessonModal> createState() => _LessonModalState();
}

class _LessonModalState extends ConsumerState<LessonModal>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late final DraggableScrollableController _sheetCtrl;
  late final AnimationController _springCtrl;
  bool _dismissing = false;
  bool _hapticOpenFired = false;

  late LessonModel _lesson;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 600.0,
    damping: 38.0,
  );

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _sheetCtrl = DraggableScrollableController();
    _sheetCtrl.addListener(_onSheetSize);
    _springCtrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onSpring);
  }

  void _onSheetSize() {
    if (!_sheetCtrl.isAttached) return;
    final s = _sheetCtrl.size;
    if (s >= 0.97 && !_hapticOpenFired) {
      _hapticOpenFired = true;
      HapticFeedback.mediumImpact();
    } else if (s < 0.97) {
      _hapticOpenFired = false;
    }
    // Pop handled directly in _onDragEnd — no race with barrier animation
  }

  void _onSpring() {
    // Only snaps back to 1.0, never dismisses
    if (!_sheetCtrl.isAttached) return;
    _sheetCtrl.jumpTo(_springCtrl.value.clamp(0.0, 1.0));
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_sheetCtrl.isAttached || _dismissing) return;
    _springCtrl.stop();
    final delta = -d.primaryDelta! / MediaQuery.of(context).size.height;
    _sheetCtrl.jumpTo((_sheetCtrl.size + delta).clamp(0.0, 1.0));
  }

  void _onDragEnd(DragEndDetails d) {
    if (!_sheetCtrl.isAttached || _dismissing) return;
    final screenH = MediaQuery.of(context).size.height;
    final velocity = -(d.primaryVelocity ?? 0) / screenH;
    final shouldClose =
        velocity < -1.2 || (_sheetCtrl.size < 0.4 && velocity <= 0);
    if (shouldClose) {
      _dismissing = true;
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    HapticFeedback.mediumImpact();
    _springCtrl.value = _sheetCtrl.size;
    _springCtrl.animateWith(
      SpringSimulation(_spring, _sheetCtrl.size, 1.0, velocity),
    );
  }

  @override
  void dispose() {
    _sheetCtrl.removeListener(_onSheetSize);
    _springCtrl.removeListener(_onSpring);
    _springCtrl.dispose();
    _sheetCtrl.dispose();
    super.dispose();
  }

  // ── Status update ─────────────────────────────────────────────────────────
  Future<void> _updateStatus(String status, {String? cancelledBy}) async {
    setState(() => _loading = true);
    final month = ref.read(selectedMonthProvider);
    final monthYear = DateFormat('yyyy-MM').format(month);
    try {
      final dio = ref.read(dioProvider);
      final body = <String, dynamic>{'status': status};
      if (cancelledBy != null) body['cancelled_by'] = cancelledBy;
      await dio.patch('/lessons/${_lesson.id}/status', data: body);

      final extraMonthYears = <String>{};

      // When reverting to scheduled, the backend also cancels any orphaned
      // makeup lessons. If the makeup was in a DIFFERENT month, invalidate
      // that month too so it disappears from the calendar immediately.
      if (status == 'scheduled' && _lesson.makeupDate != null) {
        final makeupMonthYear =
            DateFormat('yyyy-MM').format(_lesson.makeupDate!);
        extraMonthYears.add(makeupMonthYear);
        // Also invalidate the original lesson's month (may differ from selected)
        final lessonMonthYear =
            DateFormat('yyyy-MM').format(_lesson.scheduledDate);
        extraMonthYears.add(lessonMonthYear);
      }
      invalidateMonthData(ref, monthYear, extraMonthYears: extraMonthYears);

      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Makeup: date picker → create makeup lesson ────────────────────────────
  Future<void> _markMakeup() async {
    final now = DateTime.now();
    final nav = Navigator.of(context);
    final snackContext = nav.context;
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('ru'),
      builder: (context, child) {
        final base = Theme.of(context).colorScheme;
        final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
            CosmoThemeTokens.darkInternals;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: base.copyWith(
              primary: tokens.primaryAccent,
              onPrimary: isDark ? Colors.black : Colors.white,
              surface: tokens.backgroundMid,
              onSurface: tokens.primaryText,
              surfaceContainer: tokens.backgroundNear,
              surfaceContainerHigh: tokens.backgroundNear,
              surfaceContainerHighest: tokens.surface,
              onSurfaceVariant: tokens.mutedText,
              outline: tokens.surfaceBorder,
              secondaryContainer:
                  tokens.primaryAccent.withValues(alpha: NebulaAlpha.border),
              onSecondaryContainer: tokens.primaryAccent,
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: tokens.backgroundMid,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() => _loading = true);
    final pickedMonthYear = DateFormat('yyyy-MM').format(picked);
    final originalMonthYear =
        DateFormat('yyyy-MM').format(_lesson.scheduledDate);
    try {
      final dio = ref.read(dioProvider);
      await dio.post(
        '/lessons/${_lesson.id}/makeup',
        data: {'makeup_date': DateFormat('yyyy-MM-dd').format(picked)},
      );
      invalidateMonthData(
        ref,
        originalMonthYear,
        extraMonthYears: [pickedMonthYear],
      );
      HapticFeedback.mediumImpact();
      if (!mounted || !snackContext.mounted) return;
      nav.pop();
      showNebulaSnackBar(
        snackContext,
        title: 'Отработка добавлена',
        message: DateFormat('d MMMM', 'ru').format(picked),
        tone: NebulaSnackTone.info,
      );
    } on Exception catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    showNebulaSnackBar(
      context,
      title: 'Не удалось обновить урок',
      message:
          parseApiError(e, fallback: 'Проверь подключение и попробуй ещё раз'),
      tone: NebulaSnackTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final dateStr =
        DateFormat('d MMMM yyyy', 'ru').format(lesson.scheduledDate);
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;

    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final isTeacherCancelled =
        lesson.status == 'cancelled' && lesson.cancelledBy == 'teacher';
    final isStudentFault = lesson.status == 'missed' ||
        (lesson.status == 'cancelled' && lesson.cancelledBy == 'student');
    final needsMakeup = isTeacherCancelled || isStudentFault;
    // Only allow scheduling a makeup when no makeup is pending or done yet
    final canMarkMakeup = needsMakeup && lesson.makeupStatus == 'none';

    return HideTopIslandOnFullSheetExpand(
      child: DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: 0.65,
      minChildSize: 0.0,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [1.0],
      expand: false,
      builder: (context, scrollCtrl) {
        return NebulaModalSurface(
          containerKey: const ValueKey('lesson-modal-surface'),
          child: Column(
            children: [
              // ── Handle ────────────────────────────────────────────────
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: const _SheetHandle(),
              ),

              // ── Content ───────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad + 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row
                      Row(children: [
                        _StatusBadge(
                            status: lesson.status,
                            cancelledBy: lesson.cancelledBy),
                        if (lesson.isMakeup) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: NebulaColors.nebulaPurple
                                  .withValues(alpha: NebulaAlpha.subtle),
                              borderRadius: NebulaRadii.pillBorder,
                              border: Border.all(
                                  color: NebulaColors.nebulaPurple
                                      .withValues(alpha: NebulaAlpha.medium)),
                            ),
                            child: Text(
                              'ОТРАБОТКА',
                              style: NebulaTypography.of(context)
                                  .overline
                                  .copyWith(color: NebulaColors.nebulaPurple),
                            ),
                          ),
                        ],
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lesson.studentName ?? 'Ученик',
                            style: NebulaTypography.of(context).titleL.copyWith(
                                color: tokens.primaryText, letterSpacing: -0.5),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        '$dateStr${lesson.scheduledTime != null ? ' · ${lesson.scheduledTime}' : ''}',
                        style: NebulaTypography.of(context)
                            .bodyS
                            .copyWith(color: tokens.mutedText),
                      ),
                      if (lesson.instrumentName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          lesson.instrumentName!,
                          style: NebulaTypography.of(context)
                              .bodyM
                              .copyWith(color: NebulaColors.nebulaPurple),
                        ),
                      ],

                      // ── Makeup block ────────────────────────────────
                      if (needsMakeup) ...[
                        const SizedBox(height: 16),
                        _MakeupBlock(
                          makeupStatus: lesson.makeupStatus,
                          makeupDate: lesson.makeupDate,
                          isTeacherFault: isTeacherCancelled,
                        ),
                      ],

                      if (lesson.notes != null && lesson.notes!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        NebulaSurface(
                          dense: true,
                          radiusRole: NebulaRadiusRole.control,
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            lesson.notes!,
                            style: NebulaTypography.of(context)
                                .bodyM
                                .copyWith(color: tokens.secondaryText),
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),

                      // ── Action area ──────────────────────────────────
                      if (!_loading) ...[
                        if (lesson.status == 'scheduled') ...[
                          _StatusDrumPicker(
                            onConfirm: (status, {cancelledBy}) =>
                                _updateStatus(status, cancelledBy: cancelledBy),
                          ),
                        ] else ...[
                          if (canMarkMakeup) ...[
                            StellarButton(
                              label: 'Отработать урок',
                              color: NebulaColors.auroraCyan,
                              icon: Icons.event_repeat_rounded,
                              onPressed: _markMakeup,
                            ),
                            const SizedBox(height: 12),
                          ],
                          StellarButton(
                            label: 'Вернуть как запланированный',
                            color: tokens.mutedText,
                            icon: Icons.restore_rounded,
                            onPressed: () => _updateStatus('scheduled'),
                          ),
                        ],
                      ] else
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: OrbitLoader(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Makeup block
// ─────────────────────────────────────────────────────────────────────────────

class _MakeupBlock extends StatelessWidget {
  final String makeupStatus;
  final DateTime? makeupDate;
  final bool isTeacherFault;

  const _MakeupBlock({
    required this.makeupStatus,
    this.makeupDate,
    this.isTeacherFault = false,
  });

  @override
  Widget build(BuildContext context) {
    // ── State 1: makeup confirmed ──────────────────────────────────────────
    if (makeupStatus == 'done' && makeupDate != null) {
      final dateStr = DateFormat('d MMMM yyyy', 'ru').format(makeupDate!);
      return _MakeupChip(
        color: NebulaColors.successMint,
        icon: Icons.check_circle_rounded,
        title: 'Отработано',
        subtitle: dateStr,
      );
    }

    // ── State 2: makeup scheduled, waiting for confirmation ───────────────
    if (makeupStatus == 'scheduled' && makeupDate != null) {
      final dateStr = DateFormat('d MMMM yyyy', 'ru').format(makeupDate!);
      return _MakeupChip(
        color: NebulaColors.stellarBlue,
        icon: Icons.event_repeat_rounded,
        title: 'Отработка запланирована',
        subtitle: dateStr,
      );
    }

    // ── State 3: no makeup yet ─────────────────────────────────────────────
    final debtLabel = isTeacherFault
        ? 'Долг педагога — урок не отработан'
        : 'Ожидает отработки';
    return _MakeupChip(
      color: NebulaColors.warningAmber,
      icon: Icons.warning_amber_rounded,
      title: debtLabel,
      subtitle: null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Reusable coloured info chip used inside _MakeupBlock.
class _MakeupChip extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String? subtitle;

  const _MakeupChip({
    required this.color,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: NebulaAlpha.mist),
        borderRadius: NebulaRadii.controlBorder,
        border: Border.all(color: color.withValues(alpha: NebulaAlpha.accent)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: type.bodyS
                    .copyWith(color: color, fontWeight: FontWeight.w600),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: type.labelS.copyWith(
                      color: tokens?.mutedText ?? NebulaColors.dimText),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 10),
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color:
                  (Theme.of(context).extension<CosmoThemeTokens>()?.mutedText ??
                          NebulaColors.dimText)
                      .withValues(alpha: NebulaAlpha.medium),
              borderRadius: NebulaRadii.compactControlBorder,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final String? cancelledBy;

  const _StatusBadge({required this.status, this.cancelledBy});

  @override
  Widget build(BuildContext context) {
    final color = NebulaColors.lessonStatus(status);

    String label;
    if (status == 'cancelled') {
      label =
          cancelledBy == 'teacher' ? 'Отменён (педагог)' : 'Отменён (ученик)';
    } else {
      const labels = {
        'scheduled': 'Запланирован',
        'attended': 'Проведён',
        'missed': 'Пропуск',
      };
      label = labels[status] ?? status;
    }

    final type = NebulaTypography.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: NebulaAlpha.subtle),
        borderRadius: NebulaRadii.pillBorder,
        border: Border.all(color: color.withValues(alpha: NebulaAlpha.medium)),
      ),
      child: Text(
        label,
        style: type.labelS.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Desktop version — рендерится внутри Dialog без DraggableScrollableSheet
// ─────────────────────────────────────────────────────────────────────────────

class _LessonModalDesktop extends ConsumerStatefulWidget {
  final LessonModel lesson;
  const _LessonModalDesktop({required this.lesson});

  @override
  ConsumerState<_LessonModalDesktop> createState() =>
      _LessonModalDesktopState();
}

class _LessonModalDesktopState extends ConsumerState<_LessonModalDesktop> {
  bool _loading = false;
  late LessonModel _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
  }

  Future<void> _updateStatus(String status, {String? cancelledBy}) async {
    setState(() => _loading = true);
    final month = ref.read(selectedMonthProvider);
    final monthYear = DateFormat('yyyy-MM').format(month);
    try {
      final dio = ref.read(dioProvider);
      final body = <String, dynamic>{'status': status};
      if (cancelledBy != null) body['cancelled_by'] = cancelledBy;
      await dio.patch('/lessons/${_lesson.id}/status', data: body);
      final extraMonthYears = <String>{};
      if (status == 'scheduled' && _lesson.makeupDate != null) {
        final makeupMonthYear =
            DateFormat('yyyy-MM').format(_lesson.makeupDate!);
        extraMonthYears.add(makeupMonthYear);
      }
      invalidateMonthData(ref, monthYear, extraMonthYears: extraMonthYears);
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markMakeup() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('ru'),
    );
    if (picked == null || !mounted) return;
    setState(() => _loading = true);
    final pickedMonthYear = DateFormat('yyyy-MM').format(picked);
    final originalMonthYear =
        DateFormat('yyyy-MM').format(_lesson.scheduledDate);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/lessons/${_lesson.id}/makeup',
          data: {'makeup_date': DateFormat('yyyy-MM-dd').format(picked)});
      invalidateMonthData(
        ref,
        originalMonthYear,
        extraMonthYears: [pickedMonthYear],
      );
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    showNebulaSnackBar(
      context,
      title: 'Не удалось обновить урок',
      message:
          parseApiError(e, fallback: 'Проверь подключение и попробуй ещё раз'),
      tone: NebulaSnackTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final dateStr =
        DateFormat('d MMMM yyyy', 'ru').format(lesson.scheduledDate);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final isTeacherCancelled =
        lesson.status == 'cancelled' && lesson.cancelledBy == 'teacher';
    final isStudentFault = lesson.status == 'missed' ||
        (lesson.status == 'cancelled' && lesson.cancelledBy == 'student');
    final needsMakeup = isTeacherCancelled || isStudentFault;
    final canMarkMakeup = needsMakeup && lesson.makeupStatus == 'none';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Close + Header ────────────────────────────────────────────────
          Row(
            children: [
              _StatusBadge(
                  status: lesson.status, cancelledBy: lesson.cancelledBy),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: tokens.mutedText, size: 20),
                onPressed: () => Navigator.pop(context),
                splashRadius: 16,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            lesson.studentName ?? 'Ученик',
            style: NebulaTypography.of(context).titleL.copyWith(
                  color: tokens.primaryText,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '$dateStr${lesson.scheduledTime != null ? ' · ${lesson.scheduledTime}' : ''}',
            style: NebulaTypography.of(context)
                .bodyS
                .copyWith(color: tokens.mutedText),
          ),
          if (lesson.instrumentName != null) ...[
            const SizedBox(height: 4),
            Text(
              lesson.instrumentName!,
              style: NebulaTypography.of(context)
                  .bodyM
                  .copyWith(color: NebulaColors.nebulaPurple),
            ),
          ],

          if (needsMakeup) ...[
            const SizedBox(height: 16),
            _MakeupBlock(
              makeupStatus: lesson.makeupStatus,
              makeupDate: lesson.makeupDate,
              isTeacherFault: isTeacherCancelled,
            ),
          ],

          if (lesson.notes != null && lesson.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            NebulaSurface(
              dense: true,
              radiusRole: NebulaRadiusRole.control,
              padding: const EdgeInsets.all(14),
              child: Text(lesson.notes!,
                  style: NebulaTypography.of(context)
                      .bodyM
                      .copyWith(color: tokens.secondaryText)),
            ),
          ],

          const SizedBox(height: 28),

          // ── Actions ───────────────────────────────────────────────────────
          if (!_loading) ...[
            if (lesson.status == 'scheduled') ...[
              _StatusDrumPicker(
                onConfirm: (status, {cancelledBy}) =>
                    _updateStatus(status, cancelledBy: cancelledBy),
              ),
            ] else ...[
              if (canMarkMakeup) ...[
                StellarButton(
                  label: 'Отработать урок',
                  color: NebulaColors.auroraCyan,
                  icon: Icons.event_repeat_rounded,
                  onPressed: _markMakeup,
                ),
                const SizedBox(height: 10),
              ],
              StellarButton(
                label: 'Вернуть как запланированный',
                color: tokens.mutedText,
                icon: Icons.restore_rounded,
                onPressed: () => _updateStatus('scheduled'),
              ),
            ],
          ] else
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: OrbitLoader(),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _StatusDrumPicker — NebulaDrumPicker wired to lesson status actions
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDrumPicker extends StatefulWidget {
  final Future<void> Function(String status, {String? cancelledBy}) onConfirm;

  const _StatusDrumPicker({required this.onConfirm});

  @override
  State<_StatusDrumPicker> createState() => _StatusDrumPickerState();
}

class _StatusDrumPickerState extends State<_StatusDrumPicker> {
  static const _labels = [
    'Урок проведён',
    'Ученик не пришёл',
    'Отменить (педагог)',
  ];
  static const _statuses = ['attended', 'missed', 'cancelled'];
  static const _cancelledBy = [null, null, 'teacher'];
  static const _colors = [
    NebulaColors.successMint,
    NebulaColors.errorRose,
    NebulaColors.warningAmber,
  ];

  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        NebulaDrumPicker(
          items: _labels,
          initialIndex: _idx,
          glowColor: _colors[_idx],
          itemExtent: 48,
          fontSize: 16,
          onChanged: (i) => setState(() => _idx = i),
        ),
        const SizedBox(height: 14),
        StellarButton(
          label: 'Подтвердить',
          color: _colors[_idx],
          icon: Icons.check_rounded,
          onPressed: () => widget.onConfirm(_statuses[_idx],
              cancelledBy: _cancelledBy[_idx]),
        ),
      ],
    );
  }
}
