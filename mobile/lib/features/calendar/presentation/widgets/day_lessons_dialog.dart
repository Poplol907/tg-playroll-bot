part of '../screens/calendar_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Desktop: day-lessons dialog (replaces DraggableScrollableSheet on macOS/Win)
// ─────────────────────────────────────────────────────────────────────────────

class _DayLessonsDialog extends ConsumerStatefulWidget {
  final DateTime date;
  final List<dynamic> lessons;

  const _DayLessonsDialog({required this.date, required this.lessons});

  @override
  ConsumerState<_DayLessonsDialog> createState() => _DayLessonsDialogState();
}

class _DayLessonsDialogState extends ConsumerState<_DayLessonsDialog> {
  late List<LessonModel> _localLessons;

  @override
  void initState() {
    super.initState();
    _localLessons = widget.lessons.cast<LessonModel>().toList();
  }

  void _openAddLesson() {
    final monthYear = DateFormat('yyyy-MM').format(widget.date);
    AdaptiveModal.show(
      context,
      builder: (_) => _AddLessonSheet(
        date: widget.date,
        onCreated: () {
          invalidateMonthData(ref, monthYear);
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  String _lessonWord(int n) {
    if (n % 10 == 1 && n % 100 != 11) return 'урок';
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) {
      return 'урока';
    }
    return 'уроков';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final dateStr = DateFormat('d MMMM', 'ru').format(widget.date);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NebulaTypography.of(context)
                          .titleL
                          .copyWith(color: tokens.primaryText),
                    ),
                    Text(
                      '${_localLessons.length} ${_lessonWord(_localLessons.length)}',
                      style: NebulaTypography.of(context)
                          .labelM
                          .copyWith(color: tokens.mutedText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.close_rounded,
                    color: tokens.mutedText, size: 20),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: NebulaColors.surfaceBorder),
          const SizedBox(height: 12),

          // ── Lesson list ──────────────────────────────────────────────────
          ..._localLessons.map((l) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: JiggleDeleteWrapper(
                borderRadius: NebulaTokens.radiusSM,
                onTap: () {
                  Navigator.pop(context);
                  LessonModal.show(context, l);
                },
                onDeleteConfirmed: () async {
                  final nav = Navigator.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final confirmed = await NebulaDialog.confirm(
                    context,
                    title: 'Удалить урок?',
                    message: 'Это действие нельзя отменить.',
                    confirmLabel: 'Удалить',
                    destructive: true,
                  );
                  if (confirmed != true) return;
                  final removedLesson = l;
                  final lessonMonthYear =
                      DateFormat('yyyy-MM').format(l.scheduledDate);
                  if (mounted) {
                    setState(() => _localLessons.remove(removedLesson));
                  }
                  if (_localLessons.isEmpty && mounted) nav.pop();
                  try {
                    await ref
                        .read(calendarRepositoryProvider)
                        .deleteLesson(removedLesson.id);
                    if (mounted) {
                      invalidateMonthData(ref, lessonMonthYear);
                    }
                  } catch (e) {
                    final is404 =
                        e is DioException && e.response?.statusCode == 404;
                    if (is404) {
                      if (mounted) {
                        invalidateMonthData(ref, lessonMonthYear);
                      }
                    } else {
                      if (mounted) {
                        setState(() => _localLessons.insert(
                            _localLessons.length, removedLesson));
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              parseApiError(
                                e,
                                fallback:
                                    'Проверь подключение и попробуй ещё раз',
                              ),
                            ),
                            backgroundColor: NebulaColors.errorRose,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: l.statusColor.withValues(alpha: NebulaAlpha.mist),
                    borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
                    border: Border.all(
                        color: l.statusColor
                            .withValues(alpha: NebulaAlpha.border)),
                  ),
                  child: Row(
                    children: [
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
                              Text('ОТРАБОТКА',
                                  style: NebulaTypography.of(context)
                                      .overline
                                      .copyWith(
                                          color: NebulaColors.nebulaPurple)),
                            if (!l.isMakeup && l.makeupStatus == 'scheduled')
                              Text('⏳ Отработка запланирована',
                                  style: NebulaTypography.of(context)
                                      .overline
                                      .copyWith(
                                          color: NebulaColors.stellarBlue,
                                          fontWeight: FontWeight.w500)),
                            if (!l.isMakeup && l.makeupStatus == 'done')
                              Text('✓ Урок отработан',
                                  style: NebulaTypography.of(context)
                                      .overline
                                      .copyWith(
                                          color: NebulaColors.successMint)),
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
              ),
            );
          }),

          const SizedBox(height: 8),

          // ── Add lesson ───────────────────────────────────────────────────
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _openAddLesson,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: NebulaColors.stellarBlue
                      .withValues(alpha: NebulaAlpha.subtle),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusMD),
                  border: Border.all(
                      color: NebulaColors.stellarBlue
                          .withValues(alpha: NebulaAlpha.medium)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_rounded,
                        color: NebulaColors.stellarBlue, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Добавить урок',
                      style: NebulaTypography.of(context).bodyM.copyWith(
                            color: NebulaColors.stellarBlue,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
