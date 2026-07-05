part of '../screens/calendar_screen.dart';

// ─────────────────────────────────────────────
//  Add single lesson sheet
// ─────────────────────────────────────────────

class _AddLessonSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final VoidCallback onCreated;

  const _AddLessonSheet({required this.date, required this.onCreated});

  @override
  ConsumerState<_AddLessonSheet> createState() => _AddLessonSheetState();
}

class _AddLessonSheetState extends ConsumerState<_AddLessonSheet> {
  StudentModel? _selectedStudent;
  String? _selectedTime;
  bool _loading = false;

  static final _timeSlots = _buildSlots();

  static List<String> _buildSlots() {
    final slots = <String>[];
    int m = 8 * 60 + 15; // 08:15
    while (m <= 21 * 60) {
      final h = m ~/ 60;
      final min = m % 60;
      slots.add(
          '${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
      m += 45;
    }
    return slots;
  }

  Future<void> _submit() async {
    final student = _selectedStudent;
    if (student == null || student.studentTeacherId == null) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(calendarRepositoryProvider);
      await repo.createLesson(
        studentTeacherId: student.studentTeacherId!,
        scheduledDate: DateFormat('yyyy-MM-dd').format(widget.date),
        scheduledTime: _selectedTime,
      );
      HapticFeedback.mediumImpact();
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        showNebulaSnackBar(
          context,
          title: 'Не удалось добавить урок',
          message: parseApiError(e, fallback: 'Проверь данные и подключение'),
          tone: NebulaSnackTone.error,
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final dateStr = DateFormat('d MMMM', 'ru').format(widget.date);
    final isDesktop = AppPlatform.isDesktop;

    // Build form content (no modal chrome — chrome added per-platform below)
    final type = NebulaTypography.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final formContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Добавить урок · $dateStr',
          style: type.titleM.copyWith(color: tokens.primaryText),
        ),
        const SizedBox(height: 20),

        // ── Student picker ──────────────────────────────────────────────────
        Text(
          'УЧЕНИК',
          style: type.overline.copyWith(color: tokens.mutedText),
        ),
        const SizedBox(height: 8),
        studentsAsync.when(
          loading: () => const Center(child: OrbitLoader()),
          error: (_, __) => AppInlineErrorCard(
            message: 'Не удалось загрузить учеников',
            onRetry: () => ref.invalidate(studentsProvider),
          ),
          data: (students) {
            final eligible = students
                .where((s) =>
                    s.studentTeacherId != null &&
                    (s.status == 'active' || s.status == 'ACTIVE'))
                .toList();
            if (eligible.isEmpty) {
              return Text(
                'Нет активных учеников',
                style: type.bodyM.copyWith(color: tokens.mutedText),
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 44.0 * eligible.length.clamp(1, 5) + 8,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: eligible.length,
                itemBuilder: (_, i) {
                  final s = eligible[i];
                  final selected = _selectedStudent?.id == s.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStudent = s),
                    child: Container(
                      height: 44,
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? tokens.primaryAccent
                                .withValues(alpha: NebulaAlpha.subtle)
                            : tokens.surface,
                        borderRadius: NebulaRadii.controlBorder,
                        border: Border.all(
                          color: selected
                              ? tokens.primaryAccent
                                  .withValues(alpha: NebulaAlpha.strong)
                              : tokens.surfaceBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? tokens.primaryAccent
                                  : tokens.mutedText
                                      .withValues(alpha: NebulaAlpha.medium),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.fullName,
                            style: type.bodyM.copyWith(
                              color: selected
                                  ? tokens.primaryText
                                  : tokens.mutedText,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // ── Time picker ─────────────────────────────────────────────────────
        Text(
          'ВРЕМЯ',
          style: type.overline.copyWith(color: tokens.mutedText),
        ),
        const SizedBox(height: 8),
        // Барабан вместо системного прямоугольного дропдауна — тот же
        // выбор, что у статуса урока; «Без времени» — первый пункт.
        Container(
          padding: const EdgeInsets.symmetric(vertical: NebulaTokens.sp4),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: NebulaRadii.controlBorder,
            border: Border.all(color: tokens.surfaceBorder),
          ),
          child: NebulaDrumPicker(
            items: ['Без времени', ..._timeSlots],
            initialIndex: _selectedTime == null
                ? 0
                : _timeSlots.indexOf(_selectedTime!) + 1,
            glowColor: tokens.focusAccent,
            itemExtent: 38,
            fontSize: 16,
            onChanged: (i) => setState(
                () => _selectedTime = i == 0 ? null : _timeSlots[i - 1]),
          ),
        ),
        const SizedBox(height: 24),

        // ── Submit ──────────────────────────────────────────────────────────
        StellarButton(
          label: 'Добавить урок',
          loading: _loading,
          onPressed: (_selectedStudent != null && !_loading) ? _submit : null,
          icon: Icons.add_rounded,
        ),
      ],
    );

    // Desktop: AdaptiveModal handles the glass surface — just pad the content
    if (isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: formContent,
      );
    }

    // Mobile: bottom sheet chrome + handle pill
    final bottomPad = MediaQuery.of(context).viewPadding.bottom;
    return ClipRRect(
      borderRadius: NebulaRadii.sheetTopBorder,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 24),
        decoration: BoxDecoration(
          color: tokens.denseSurface,
          borderRadius: NebulaRadii.sheetTopBorder,
          border: Border(
            top: BorderSide(color: tokens.surfaceBorder, width: 1),
            left: BorderSide(color: tokens.surfaceBorder, width: 1),
            right: BorderSide(color: tokens.surfaceBorder, width: 1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle pill
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: tokens.mutedText.withValues(alpha: NebulaAlpha.strong),
                  borderRadius: NebulaRadii.compactControlBorder,
                ),
              ),
            ),
            formContent,
          ],
        ),
      ),
    );
  }
}
