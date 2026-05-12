import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../shared/models/lesson.dart';

// ─────────────────────────────────────────────
//  ConstellationCalendar
// ─────────────────────────────────────────────

class ConstellationCalendar extends StatefulWidget {
  final DateTime month;
  final List<LessonModel> lessons;
  final ValueChanged<DateTime>? onDayTap;
  final bool enableAmbientMotion;
  final VoidCallback? onDebugAnimationTick;

  const ConstellationCalendar({
    super.key,
    required this.month,
    required this.lessons,
    this.onDayTap,
    this.enableAmbientMotion = false,
    this.onDebugAnimationTick,
  });

  @override
  State<ConstellationCalendar> createState() => _ConstellationCalendarState();
}

class _ConstellationCalendarState extends State<ConstellationCalendar>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _warnCtrl;
  late Animation<double> _pulse;
  late Animation<double> _glow;
  late Animation<double> _warn;

  Map<int, List<LessonModel>> _lessonsByDay = {};

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
      value: 0.5,
    )..addListener(_debugAnimationTick);

    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
      value: 0.8,
    );

    _warnCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      value: 0.8,
    );

    _pulse = Tween<double>(begin: 0.8, end: 1.2)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _glow = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _warn = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _warnCtrl, curve: Curves.easeInOut));

    _buildLessonMap();
  }

  void _debugAnimationTick() {
    if (!widget.enableAmbientMotion || !_pulseCtrl.isAnimating) return;
    widget.onDebugAnimationTick?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAmbientMotion();
  }

  void _syncAmbientMotion() {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (reduce || !widget.enableAmbientMotion) {
      _pulseCtrl
        ..stop()
        ..value = 0.5;
      _glowCtrl
        ..stop()
        ..value = 0.8;
      _warnCtrl
        ..stop()
        ..value = 0.8;
      return;
    }

    if (!_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    }
    if (!_glowCtrl.isAnimating) {
      _glowCtrl.repeat(reverse: true);
    }
    if (!_warnCtrl.isAnimating) {
      _warnCtrl.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ConstellationCalendar old) {
    super.didUpdateWidget(old);
    if (old.lessons != widget.lessons || old.month != widget.month) {
      _buildLessonMap();
    }
    if (old.enableAmbientMotion != widget.enableAmbientMotion) {
      _syncAmbientMotion();
    }
  }

  void _buildLessonMap() {
    _lessonsByDay = {};
    for (final l in widget.lessons) {
      if (l.scheduledDate.year == widget.month.year &&
          l.scheduledDate.month == widget.month.month) {
        final d = l.scheduledDate.day;
        _lessonsByDay.putIfAbsent(d, () => []).add(l);
      }
    }
  }

  @override
  void dispose() {
    _pulseCtrl.removeListener(_debugAnimationTick);
    _pulseCtrl.dispose();
    _glowCtrl.dispose();
    _warnCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulse, _glow, _warn]),
      builder: (context, _) {
        return _CalendarBody(
          month: widget.month,
          lessonsByDay: _lessonsByDay,
          pulse: _pulse.value,
          glow: _glow.value,
          warn: _warn.value,
          onDayTap: widget.onDayTap,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
//  Calendar body with CustomPaint overlay
// ─────────────────────────────────────────────

class _CalendarBody extends StatelessWidget {
  final DateTime month;
  final Map<int, List<LessonModel>> lessonsByDay;
  final double pulse;
  final double glow;
  final double warn;
  final ValueChanged<DateTime>? onDayTap;

  const _CalendarBody({
    required this.month,
    required this.lessonsByDay,
    required this.pulse,
    required this.glow,
    required this.warn,
    required this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final firstWeekday = DateTime(month.year, month.month, 1).weekday;
    final leadingEmpty = firstWeekday - 1;
    final today = DateTime.now();

    // Pre-compute grid structure (independent of layout constraints)
    final totalCells = leadingEmpty + daysInMonth;
    final trailingEmpty = (7 - (totalCells % 7)) % 7;
    final itemCount = totalCells + trailingEmpty;
    final rows = itemCount ~/ 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WeekHeader(),
        const SizedBox(height: 8),
        // Expanded lets LayoutBuilder receive bounded height on desktop
        // (inside Expanded(NebulaSurface)) and on mobile (inside AspectRatio).
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Cell size = min of width-based and height-based limits so the
              // entire grid fits without scrolling regardless of screen shape.
              final byWidth = constraints.maxWidth / 7;
              final byHeight = constraints.maxHeight.isFinite
                  ? constraints.maxHeight / rows
                  : byWidth;
              final cellSize = min(byWidth, byHeight);
              final gridH = rows * cellSize;
              // childAspectRatio = cellWidth / cellHeight
              final cellAspect = byWidth / cellSize;

              final Map<int, Offset> dayCentres = {};
              for (int d = 1; d <= daysInMonth; d++) {
                final idx = leadingEmpty + d - 1;
                dayCentres[d] = Offset(
                  (idx % 7) * byWidth + byWidth / 2,
                  (idx ~/ 7) * cellSize + cellSize / 2,
                );
              }

              return SizedBox(
                height: gridH,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: Size(constraints.maxWidth, gridH),
                      painter: _ConstellationLinesPainter(
                        lessonDays: lessonsByDay.keys.toList()..sort(),
                        dayCentres: dayCentres,
                        glow: glow,
                        isLight: isLight,
                      ),
                    ),
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: cellAspect,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index < leadingEmpty ||
                            index - leadingEmpty + 1 > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        final day = index - leadingEmpty + 1;
                        final date = DateTime(month.year, month.month, day);
                        final isToday = date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;
                        return _DayCell(
                          day: day,
                          date: date,
                          isToday: isToday,
                          isLight: isLight,
                          lessons: lessonsByDay[day] ?? [],
                          pulse: pulse,
                          glow: glow,
                          warn: warn,
                          onTap: () => onDayTap?.call(date),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Week header row
// ─────────────────────────────────────────────

class _WeekHeader extends StatelessWidget {
  static const _days = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Row(
      children: _days
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: isLight
                          ? const Color(0xFF6B7280)
                          : NebulaColors.ghostText,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
//  Individual day cell
// ─────────────────────────────────────────────

class _DayCell extends StatelessWidget {
  final int day;
  final DateTime date;
  final bool isToday;
  final bool isLight;
  final List<LessonModel> lessons;
  final double pulse;
  final double glow;
  final double warn;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.date,
    required this.isToday,
    required this.isLight,
    required this.lessons,
    required this.pulse,
    required this.glow,
    required this.warn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasLessons = lessons.isNotEmpty;
    final today = DateTime.now();
    final isPast = date.isBefore(DateTime(today.year, today.month, today.day));

    final isUnfilled =
        isPast && hasLessons && lessons.any((l) => l.status == 'scheduled');

    Color starColor = NebulaColors.ghostText;
    if (hasLessons) {
      if (isUnfilled) {
        starColor = NebulaColors.warningAmber;
      } else {
        starColor = lessons.first.statusColor;
      }
    }
    if (isToday) starColor = NebulaColors.auroraCyan;

    final warnOpacity = isUnfilled ? warn : 0.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Today pulse ring
            if (isToday)
              Container(
                width: 36 * pulse,
                height: 36 * pulse,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        NebulaColors.auroraCyan.withValues(alpha: 0.4 * glow),
                    width: 1,
                  ),
                ),
              ),

            // Warn pulse ring
            if (isUnfilled)
              Container(
                width: 34 + 6 * warn,
                height: 34 + 6 * warn,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NebulaColors.warningAmber
                        .withValues(alpha: (isLight ? 0.7 : 0.55) * warnOpacity),
                    width: 1.5,
                  ),
                  boxShadow: isLight
                      ? [
                          BoxShadow(
                            color: NebulaColors.warningAmber
                                .withValues(alpha: 0.60 * warnOpacity),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: NebulaColors.warningAmber
                                .withValues(alpha: 0.30 * warnOpacity),
                            blurRadius: 28,
                            spreadRadius: -5,
                          ),
                          BoxShadow(
                            color: NebulaColors.warningAmber
                                .withValues(alpha: 0.12 * warnOpacity),
                            blurRadius: 56,
                            spreadRadius: -10,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: NebulaColors.warningAmber
                                .withValues(alpha: 0.38 * warnOpacity),
                            blurRadius: 14,
                            spreadRadius: 3,
                          ),
                        ],
                ),
              ),

            // Star node
            Container(
              width: hasLessons ? 28 : (isToday ? 26 : 22),
              height: hasLessons ? 28 : (isToday ? 26 : 22),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnfilled
                    ? NebulaColors.warningAmber
                        .withValues(alpha: 0.08 + 0.07 * warnOpacity)
                    : (hasLessons
                        ? starColor.withValues(alpha: 0.12)
                        : (isToday
                            ? NebulaColors.auroraCyan.withValues(alpha: 0.15)
                            : Colors.transparent)),
                border: Border.all(
                  color: isUnfilled
                      ? NebulaColors.warningAmber
                          .withValues(alpha: 0.4 + 0.4 * warnOpacity)
                      : (isToday
                          ? NebulaColors.auroraCyan.withValues(alpha: 0.85)
                          : (hasLessons
                              ? starColor.withValues(alpha: isLight ? 0.75 : 0.6)
                              : NebulaColors.ghostText.withValues(alpha: 0.2))),
                  width: isToday || isUnfilled ? 1.5 : 1,
                ),
                boxShadow: (isToday || hasLessons)
                    ? isLight
                        // Spreading paint: clear core + wide soft bleed outward
                        ? [
                            BoxShadow(
                              color: starColor.withValues(alpha: 0.65 * glow),
                              blurRadius: 6,
                              spreadRadius: 0,
                            ),
                            BoxShadow(
                              color: starColor.withValues(alpha: 0.30 * glow),
                              blurRadius: 22,
                              spreadRadius: -4,
                            ),
                            BoxShadow(
                              color: starColor.withValues(alpha: 0.12 * glow),
                              blurRadius: 44,
                              spreadRadius: -8,
                            ),
                          ]
                        // Dark: focused radial glow
                        : [
                            BoxShadow(
                              color: starColor.withValues(alpha: 0.45 * glow),
                              blurRadius: 14,
                              spreadRadius: 2,
                            ),
                          ]
                    : null,
              ),
              child: Center(
                child: isUnfilled
                    ? Text(
                        '?',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: NebulaColors.warningAmber
                              .withValues(alpha: 0.6 + 0.4 * warnOpacity),
                          shadows: [
                            Shadow(
                              color: NebulaColors.warningAmber.withValues(alpha: 0.8),
                              blurRadius: 4,
                            )
                          ],
                        ),
                      )
                    : Text(
                        '$day',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.w700 : FontWeight.w400,
                          color: isToday
                              ? NebulaColors.auroraCyan
                              : (hasLessons
                                  ? starColor
                                  : (isPast
                                      ? (isLight
                                          ? const Color(0xFF9CA3AF)
                                          : NebulaColors.ghostText)
                                      : (isLight
                                          ? const Color(0xFF6B7280)
                                          : NebulaColors.dimText))),
                          shadows: isToday || hasLessons
                              ? [
                                  Shadow(
                                    color: (isToday ? NebulaColors.auroraCyan : starColor)
                                        .withValues(alpha: 0.6),
                                    blurRadius: 6,
                                  )
                                ]
                              : null,
                        ),
                      ),
              ),
            ),

            // Маленькое число поверх "?" для незаполненных дней
            if (isUnfilled)
              Positioned(
                top: 5,
                right: 5,
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 8,
                    color: NebulaColors.warningAmber.withValues(alpha: 0.6),
                  ),
                ),
              ),

            // Multi-lesson dots
            if (hasLessons && !isUnfilled && lessons.length > 1)
              Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: lessons
                      .take(3)
                      .map((l) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: l.statusColor,
                            ),
                          ))
                      .toList(),
                ),
              ),

            // Янтарные точки для незаполненного дня
            if (isUnfilled && lessons.length > 1)
              Positioned(
                bottom: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: lessons
                      .take(3)
                      .map((_) => Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: NebulaColors.warningAmber
                                  .withValues(alpha: 0.5 + 0.5 * warnOpacity),
                            ),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Constellation lines painter
// ─────────────────────────────────────────────

class _ConstellationLinesPainter extends CustomPainter {
  final List<int> lessonDays;
  final Map<int, Offset> dayCentres;
  final double glow;
  final bool isLight;

  _ConstellationLinesPainter({
    required this.lessonDays,
    required this.dayCentres,
    required this.glow,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (lessonDays.length < 2) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < lessonDays.length - 1; i++) {
      final from = dayCentres[lessonDays[i]];
      final to = dayCentres[lessonDays[i + 1]];
      if (from == null || to == null) continue;

      final dist = (to - from).distance;
      final opacity =
          (1.0 - dist / 400).clamp(0.05, isLight ? 0.55 : 0.4) * glow;

      paint.shader = LinearGradient(
        colors: [
          NebulaColors.stellarBlue.withValues(alpha: opacity),
          NebulaColors.nebulaPurple.withValues(alpha: opacity * 0.6),
        ],
      ).createShader(Rect.fromPoints(from, to));

      canvas.drawLine(from, to, paint);
    }
  }

  @override
  bool shouldRepaint(_ConstellationLinesPainter old) =>
      old.glow != glow || old.lessonDays != lessonDays || old.isLight != isLight;
}
