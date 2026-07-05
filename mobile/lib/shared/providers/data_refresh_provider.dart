import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/data/admin_repository.dart';
import '../../features/admin/data/payouts_repository.dart';
import '../../features/admin/data/rates_repository.dart';
import '../../features/calendar/presentation/providers/calendar_provider.dart';
import '../../features/rooms/data/rooms_repository.dart';
import '../../features/salary/presentation/providers/salary_provider.dart';
import '../../features/students/data/students_repository.dart';
import '../../features/students/presentation/providers/student_lessons_provider.dart';

/// Refreshes all cached views that derive from lesson facts for a month.
///
/// Use this after lesson mutations instead of manually invalidating calendar,
/// salary, and student-card providers in each screen.
void invalidateMonthData(
  WidgetRef ref,
  String monthYear, {
  Iterable<String> extraMonthYears = const [],
}) {
  // Family целиком, а не точечный ключ: раньше ключ (monthYear, teacherId)
  // собирался здесь вручную из viewAsTeacherProvider и мог разойтись с тем,
  // как его собирает сам провайдер (два независимых способа keying'а).
  // Инвалидация всей family дешёвая — живые инстансы перезагружаются, а
  // ошибка рассинхронизированного ключа исчезает как класс. Параметры месяца
  // сохранены в сигнатуре: вызовы документируют, ЧТО поменялось.
  ref.invalidate(lessonsProvider);

  ref.invalidate(salaryProvider);
  ref.invalidate(studentsProvider);
  ref.invalidate(studentLessonsProvider);
  ref.invalidate(studentSubscriptionsProvider);
}

/// Полный сброс всех user-scoped кэшей — граница смены личности.
///
/// Вызывается при logout: без этого повторный вход под ДРУГИМ аккаунтом
/// пару секунд показывал закэшированные данные предыдущего (провайдеры
/// Riverpod живут в одном контейнере и сами смену токена не видят).
/// Family-провайдеры инвалидируются целиком. Новый user-scoped провайдер —
/// добавляй сюда же.
void invalidateAllUserData(WidgetRef ref) {
  ref.invalidate(lessonsProvider);
  ref.invalidate(salaryProvider);
  ref.invalidate(ratesProvider);
  ref.invalidate(studentsProvider);
  ref.invalidate(teachersPickerProvider);
  ref.invalidate(studentLessonsProvider);
  ref.invalidate(studentSubscriptionsProvider);
  ref.invalidate(orgUsersProvider);
  ref.invalidate(studioStatsProvider);
  ref.invalidate(teacherPaidProvider);
  ref.invalidate(teacherDefaultRateProvider);
  ref.invalidate(roomsProvider);
  ref.invalidate(roomBlocksForDateProvider);
}
