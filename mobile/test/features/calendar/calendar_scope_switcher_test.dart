import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmo_studio/features/calendar/data/calendar_repository.dart';
import 'package:cosmo_studio/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/data/rooms_repository.dart';
import 'package:cosmo_studio/shared/models/lesson.dart';
import 'package:cosmo_studio/shared/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCalendarRepo extends CalendarRepository {
  _FakeCalendarRepo() : super(Dio());
  @override
  Future<List<LessonModel>> getLessons({
    required String monthYear,
    int? teacherId,
  }) async =>
      const [];
}

class _FakeRoomsRepo extends RoomsRepository {
  _FakeRoomsRepo() : super(Dio());
  @override
  Future<List<Room>> getRooms({bool includeInactive = false}) async => const [];
  @override
  Future<List<ResolvedRoomBlock>> getBlocksForDate(
    String dateYmd, {
    int? teacherId,
  }) async =>
      const [];
}

void main() {
  testWidgets(
      'calendar exposes the Ученики/Кабинеты switcher and shows the room board',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          calendarRepositoryProvider.overrideWithValue(_FakeCalendarRepo()),
          roomsRepositoryProvider.overrideWithValue(_FakeRoomsRepo()),
          currentUserProvider.overrideWithValue(
            const UserModel(id: 1, orgId: 1, login: 'admin', role: 'ADMIN'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const CalendarScreen(),
        ),
      ),
    );
    // Resolve the lessons future (avoid pumpAndSettle — ambient animations).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // Both scopes are offered; default is Ученики.
    expect(find.text('Ученики'), findsOneWidget);
    expect(find.text('Кабинеты'), findsOneWidget);

    // Switch to the room board.
    await tester.tap(find.text('Кабинеты'));
    await tester.pump(); // rebuild into the board (rooms loading)
    await tester.pump(const Duration(milliseconds: 50)); // resolve rooms/blocks

    // The rooms scope shows the digital-rooms strip + hint.
    expect(find.text('Выберите кабинет, чтобы открыть расписание'),
        findsOneWidget);
  });
}
