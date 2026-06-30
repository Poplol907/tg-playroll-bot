import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/data/admin_repository.dart';
import '../../features/admin/data/payouts_repository.dart';
import '../../features/admin/data/rates_repository.dart';
import '../../features/admin/presentation/providers/view_as_teacher_provider.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/calendar/presentation/providers/calendar_provider.dart';
import '../../features/rooms/data/rooms_repository.dart';
import '../../features/rooms/presentation/providers/room_board_providers.dart';
import '../../features/salary/presentation/providers/salary_provider.dart';
import '../../features/students/data/students_repository.dart';
import '../../features/students/presentation/providers/student_lessons_provider.dart';
import '../../shared/providers/month_provider.dart';

/// Drops every per-account cache so one user's data can never bleed into the
/// next session on the same device.
///
/// SECURITY-CRITICAL: providers here are scoped to the authenticated user.
/// When you add a new provider that fetches user-specific data (or holds
/// per-account UI state), add it here too — otherwise it will leak across an
/// account switch. Invalidating a `.family` provider clears all its instances.
void resetUserScopedData(WidgetRef ref) {
  // ── Network-backed, per-account data ──
  ref.invalidate(lessonsProvider);
  ref.invalidate(teacherPaidProvider);
  ref.invalidate(teacherDefaultRateProvider);
  ref.invalidate(orgUsersProvider);
  ref.invalidate(studioStatsProvider);
  ref.invalidate(salaryProvider);
  ref.invalidate(ratesProvider);
  ref.invalidate(studentsProvider);
  ref.invalidate(teachersPickerProvider);
  ref.invalidate(studentsByTeacherProvider);
  ref.invalidate(studentLessonsProvider);
  ref.invalidate(studentSubscriptionsProvider);
  ref.invalidate(roomsProvider);
  ref.invalidate(roomBlocksForDateProvider);

  // ── Per-account UI state ──
  ref.invalidate(viewAsTeacherProvider);
  ref.invalidate(globalMonthProvider);
  ref.invalidate(selectedDayProvider);
  ref.invalidate(boardDateProvider);
}

/// Wraps the app and resets every per-account cache whenever the authenticated
/// user identity changes (login, logout, or re-auth as a different user).
///
/// The shared root [ProviderScope] survives auth transitions — without this
/// gate, plain `FutureProvider`s keep the previous account's results and serve
/// them to the next user.
class SessionResetGate extends ConsumerWidget {
  final Widget child;
  const SessionResetGate({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int?>(
      currentUserProvider.select((u) => u?.id),
      (previousId, nextId) {
        if (previousId != nextId) resetUserScopedData(ref);
      },
    );
    return child;
  }
}
