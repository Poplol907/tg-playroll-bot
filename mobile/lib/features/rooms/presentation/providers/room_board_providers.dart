import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which scope the calendar tab shows.
enum CalendarScope { students, rooms }

final calendarScopeProvider =
    StateProvider<CalendarScope>((_) => CalendarScope.students);

/// The day currently shown on the room board (date-only, local).
final boardDateProvider = StateProvider<DateTime>((_) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
});

/// Board grid geometry (09:00–21:00, 45-minute slots).
class BoardGrid {
  static const int startMinutes = 9 * 60; // 09:00
  static const int endMinutes = 21 * 60; // 21:00
  static const int slotMinutes = 45;
  static const double slotHeight = 64; // px per 45-min slot
  static const double gutterWidth = 56;
  static const double columnWidth = 128;

  static int get slotCount =>
      ((endMinutes - startMinutes) / slotMinutes).ceil();
  static double get gridHeight => slotCount * slotHeight;

  /// Vertical offset (px) for an absolute minute value.
  static double topFor(int minutes) =>
      (minutes - startMinutes) / slotMinutes * slotHeight;

  /// Contract weekday (0=Mon … 6=Sun) for a Dart DateTime.
  static int contractWeekday(DateTime d) => d.weekday - 1;
}
