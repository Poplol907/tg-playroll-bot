part of '../screens/calendar_screen.dart';

class _DayLessonsSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final List<dynamic> lessons;

  const _DayLessonsSheet({required this.date, required this.lessons});

  @override
  ConsumerState<_DayLessonsSheet> createState() => _DayLessonsSheetState();
}

class _DayLessonsSheetState extends ConsumerState<_DayLessonsSheet>
    with SingleTickerProviderStateMixin {
  late final DraggableScrollableController _sheetCtrl;
  late final AnimationController _springCtrl;
  bool _dismissing = false;
  bool _hapticOpenFired = false;
  // Local copy of lessons — allows optimistic removal without waiting for server.
  late List<LessonModel> _localLessons;

  static const _spring = SpringDescription(
    mass: 1.0,
    stiffness: 600.0,
    damping: 38.0,
  );

  @override
  void initState() {
    super.initState();
    _localLessons = widget.lessons.cast<LessonModel>().toList();
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
    // Dismiss is handled entirely in _onDragEnd — not here.
    // Keeping the listener only for haptics.
  }

  void _onSpring() {
    // Spring is only used for snap-to-FULL animation.
    // Dismiss (snap-to-close) is handled via Navigator.pop() in _onDragEnd
    // so the modal route's barrier always clears reliably.
    if (!_sheetCtrl.isAttached) return;
    _sheetCtrl.jumpTo(_springCtrl.value.clamp(0.0, 1.0));
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_sheetCtrl.isAttached) return;
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
      // Call Navigator.pop() directly — this is the single reliable dismiss
      // path. The modal route's own exit animation fades the barrier, so
      // the dark overlay never gets stuck. Previously we animated the spring
      // to 0 and called Navigator.pop() from the listener, which was racy.
      _dismissing = true;
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Snap back to full height with spring.
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

  @override
  Widget build(BuildContext context) {
    // Capture the State's context BEFORE nested builders shadow it.
    // DraggableScrollableSheet's builder and ListView's itemBuilder both
    // use "context" as their parameter name, which hides this State's
    // context. Using a stale item context for Navigator.pop after an async
    // gap causes the black-screen crash when deleting lessons in sequence.
    final stateCtx = context;

    return DraggableScrollableSheet(
      controller: _sheetCtrl,
      initialChildSize: 0.65,
      minChildSize: 0.0,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [1.0],
      expand: false,
      builder: (_, scrollCtrl) {
        return LayoutBuilder(
          builder: (layoutCtx, constraints) {
            // During the close animation the sheet can be compressed to a
            // very small height. Rendering the full Column at < 120px causes
            // a RenderFlex overflow because the handle (28px) + header row
            // (~50px) + divider (1px) + padding already exceeds 90px.
            // Return an invisible box for that transient phase — the spring
            // closes the sheet in < 150ms so the user never notices.
            if (constraints.maxHeight < 120) {
              return const SizedBox.expand();
            }
            return _buildSheetContent(stateCtx, scrollCtrl);
          },
        );
      },
    );
  }

  Widget _buildSheetContent(
      BuildContext stateCtx, ScrollController scrollCtrl) {
    final bottomPad = MediaQuery.of(stateCtx).viewPadding.bottom;
    final dateStr = DateFormat('d MMMM', 'ru').format(widget.date);
    final tokens = Theme.of(stateCtx).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaModalSurface(
      containerKey: const ValueKey('day-lessons-modal-surface'),
      child: Column(
        children: [
          // ── Handle + header (swipe zone) ──
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: Column(
              children: [
                // Handle pill
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14, bottom: 10),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: tokens.mutedText
                              .withValues(alpha: NebulaAlpha.medium),
                          borderRadius:
                              BorderRadius.circular(NebulaTokens.radiusXS),
                        ),
                      ),
                    ),
                  ),
                ),
                // Date header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dateStr,
                        style: NebulaTypography.of(context)
                            .titleL
                            .copyWith(color: tokens.primaryText),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '${_localLessons.length} ${_lessonWord(_localLessons.length)}',
                          style: NebulaTypography.of(context)
                              .labelM
                              .copyWith(color: tokens.mutedText),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: NebulaColors.surfaceBorder),
          // Lesson list + add button
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPad + 24),
              itemCount: _localLessons.length + 1, // +1 for add button
              separatorBuilder: (_, i) => SizedBox(
                height: i == widget.lessons.length - 1 ? 16 : 10,
              ),
              itemBuilder: (_, i) {
                // Last item: "Add lesson" button
                if (i == _localLessons.length) {
                  return GestureDetector(
                    onTap: () => _showAddLesson(stateCtx),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: NebulaColors.stellarBlue
                            .withValues(alpha: NebulaAlpha.subtle),
                        borderRadius:
                            BorderRadius.circular(NebulaTokens.radiusMD),
                        border: Border.all(
                          color: NebulaColors.stellarBlue
                              .withValues(alpha: NebulaAlpha.medium),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: NebulaColors.stellarBlue,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Добавить урок',
                            style: NebulaTypography.of(context).bodyM.copyWith(
                                color: NebulaColors.stellarBlue,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final l = _localLessons[i];
                return JiggleDeleteWrapper(
                  jiggleIndex: i,
                  borderRadius: NebulaTokens.radiusSM,
                  onTap: () {
                    Navigator.pop(stateCtx);
                    LessonModal.show(stateCtx, l);
                  },
                  onDeleteConfirmed: () async {
                    // Capture both navigator and messenger BEFORE any
                    // await — using BuildContext across async gaps is
                    // a lint error and causes crashes on deactivated
                    // widget trees.
                    final nav = Navigator.of(stateCtx);
                    final confirmed = await NebulaDialog.confirm(
                      stateCtx,
                      title: 'Удалить урок?',
                      message: 'Это действие нельзя отменить.',
                      confirmLabel: 'Удалить',
                      destructive: true,
                    );
                    if (confirmed != true) return;

                    // ── Optimistic deletion ──────────────────────────
                    // Remove from local list immediately — zero freeze.
                    // Pop and invalidate happen AFTER the API call so
                    // that invalidateMonthData is never skipped because
                    // the widget unmounts before the await completes.
                    final removedLesson = l;
                    final removedIdx = _localLessons.indexOf(l);
                    final lessonMonthYear =
                        DateFormat('yyyy-MM').format(l.scheduledDate);
                    HapticFeedback.mediumImpact();
                    setState(() => _localLessons.remove(removedLesson));

                    try {
                      await ref
                          .read(calendarRepositoryProvider)
                          .deleteLesson(removedLesson.id);
                      // Invalidate calendar + salary BEFORE closing the
                      // sheet so providers are fresh when it pops.
                      if (mounted) {
                        invalidateMonthData(ref, lessonMonthYear);
                        if (_localLessons.isEmpty) {
                          _dismissing = true;
                          nav.pop();
                        }
                      }
                    } catch (e) {
                      // 404 = lesson already gone from DB (ghost
                      // lesson). Treat as success.
                      final is404 =
                          e is DioException && e.response?.statusCode == 404;
                      if (is404) {
                        if (mounted) {
                          invalidateMonthData(ref, lessonMonthYear);
                          if (_localLessons.isEmpty) {
                            _dismissing = true;
                            nav.pop();
                          }
                        }
                        return;
                      }
                      // Real error — rollback the optimistic removal.
                      if (mounted) {
                        setState(() => _localLessons.insert(
                            removedIdx.clamp(0, _localLessons.length),
                            removedLesson));
                        showNebulaSnackBar(
                          context,
                          title: 'Не удалось удалить урок',
                          message: parseApiError(
                            e,
                            fallback: 'Проверь подключение и попробуй ещё раз',
                          ),
                          tone: NebulaSnackTone.error,
                        );
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: l.statusColor.withValues(alpha: NebulaAlpha.mist),
                      borderRadius:
                          BorderRadius.circular(NebulaTokens.radiusSM),
                      border: Border.all(
                          color: l.statusColor
                              .withValues(alpha: NebulaAlpha.border)),
                    ),
                    child: Row(
                      children: [
                        // PulseIndicator: semantic dot with status animation
                        l.isMakeup
                            ? Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: NebulaColors.nebulaPurple,
                                ),
                              )
                            : PulseIndicator(status: l.status, size: 10),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.studentName ?? 'Ученик',
                                style: NebulaTypography.of(context)
                                    .titleS
                                    .copyWith(color: tokens.primaryText),
                              ),
                              if (l.isMakeup)
                                Text(
                                  'ОТРАБОТКА',
                                  style: NebulaTypography.of(context)
                                      .overline
                                      .copyWith(
                                          color: NebulaColors.nebulaPurple),
                                ),
                              // Makeup state badge on original lesson
                              if (!l.isMakeup && l.makeupStatus == 'scheduled')
                                Text(
                                  '⏳ Отработка запланирована',
                                  style: NebulaTypography.of(context)
                                      .overline
                                      .copyWith(
                                          color: NebulaColors.stellarBlue,
                                          fontWeight: FontWeight.w500),
                                ),
                              if (!l.isMakeup && l.makeupStatus == 'done')
                                Text(
                                  '✓ Урок отработан',
                                  style: NebulaTypography.of(context)
                                      .overline
                                      .copyWith(
                                          color: NebulaColors.successMint),
                                ),
                            ],
                          ),
                        ),
                        if (l.scheduledTime != null)
                          Text(
                            l.scheduledTime!,
                            style: NebulaTypography.of(context)
                                .labelM
                                .copyWith(color: tokens.mutedText),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLesson(BuildContext ctx) {
    HapticFeedback.lightImpact();
    final monthYear = DateFormat('yyyy-MM').format(widget.date);
    final sheet = _AddLessonSheet(
      date: widget.date,
      onCreated: () {
        invalidateMonthData(ref, monthYear);
        if (mounted) Navigator.of(ctx).pop();
      },
    );
    if (AppPlatform.isDesktop) {
      AdaptiveModal.show(ctx, builder: (_) => sheet);
      return;
    }
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => sheet,
    );
  }

  String _lessonWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'урок';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'урока';
    }
    return 'уроков';
  }
}
