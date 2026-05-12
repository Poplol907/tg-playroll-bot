import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Single source of truth for the active month across all screens.
/// Calendar, Salary, and Student subscriptions all read from here.
final globalMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

/// Derived string "YYYY-MM" from the global month.
final globalMonthYearProvider = Provider<String>((ref) {
  return DateFormat('yyyy-MM').format(ref.watch(globalMonthProvider));
});
