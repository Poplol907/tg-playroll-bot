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
    final formContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Добавить урок · $dateStr',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: NebulaColors.softWhite,
          ),
        ),
        const SizedBox(height: 20),

        // ── Student picker ──────────────────────────────────────────────────
        const Text(
          'УЧЕНИК',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: NebulaColors.ghostText,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        studentsAsync.when(
          loading: () => const Center(child: OrbitLoader()),
          error: (_, __) => const Text(
            'Ошибка загрузки',
            style: TextStyle(color: NebulaColors.errorRose, fontSize: 14),
          ),
          data: (students) {
            final eligible = students
                .where((s) =>
                    s.studentTeacherId != null &&
                    (s.status == 'active' || s.status == 'ACTIVE'))
                .toList();
            if (eligible.isEmpty) {
              return const Text(
                'Нет активных учеников',
                style: TextStyle(color: NebulaColors.ghostText, fontSize: 14),
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
                            ? NebulaColors.stellarBlue.withValues(alpha: 0.15)
                            : NebulaColors.nebulaSurface,
                        borderRadius:
                            BorderRadius.circular(NebulaTokens.radiusSM),
                        border: Border.all(
                          color: selected
                              ? NebulaColors.stellarBlue.withValues(alpha: 0.5)
                              : NebulaColors.surfaceBorder,
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
                                  ? NebulaColors.stellarBlue
                                  : NebulaColors.ghostText
                                      .withValues(alpha: 0.4),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            s.fullName,
                            style: TextStyle(
                              fontSize: 14,
                              color: selected
                                  ? NebulaColors.softWhite
                                  : NebulaColors.dimText,
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
        const Text(
          'ВРЕМЯ',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: NebulaColors.ghostText,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: NebulaColors.nebulaSurface,
            borderRadius: BorderRadius.circular(NebulaTokens.radiusSM),
            border: Border.all(color: NebulaColors.surfaceBorder),
          ),
          child: DropdownButton<String>(
            value: _selectedTime,
            hint: const Text(
              'Выбрать время (необязательно)',
              style: TextStyle(color: NebulaColors.ghostText, fontSize: 14),
            ),
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: NebulaColors.depthNear,
            icon: const Icon(Icons.expand_more_rounded,
                color: NebulaColors.dimText, size: 20),
            style: const TextStyle(color: NebulaColors.softWhite, fontSize: 14),
            items: _timeSlots
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _selectedTime = v),
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
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(NebulaTokens.radiusLG),
      ),
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPad + 24),
        decoration: const BoxDecoration(
          color: NebulaColors.denseNebulaSurface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NebulaTokens.radiusLG),
          ),
          border: Border(
            top: BorderSide(color: NebulaColors.surfaceBorder, width: 1),
            left: BorderSide(color: NebulaColors.surfaceBorder, width: 1),
            right: BorderSide(color: NebulaColors.surfaceBorder, width: 1),
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
                  color: NebulaColors.dimText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusXS),
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
