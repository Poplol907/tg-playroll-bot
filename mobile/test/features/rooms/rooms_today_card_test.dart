import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/data/rooms_repository.dart';
import 'package:cosmo_studio/features/rooms/presentation/widgets/rooms_today_card.dart';
import 'package:cosmo_studio/shared/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRoomsRepo extends RoomsRepository {
  _FakeRoomsRepo() : super(Dio());
  @override
  Future<List<ResolvedRoomBlock>> getBlocksForDate(
    String dateYmd, {
    int? teacherId,
  }) async =>
      const [
        ResolvedRoomBlock(
          id: 1,
          roomId: 1,
          roomName: 'Зал A',
          teacherUserId: 7,
          teacherName: 'Иван',
          startTime: '10:00',
          endTime: '10:45',
          isRecurring: true,
        ),
      ];
}

Widget _wrap({required String role}) => ProviderScope(
      overrides: [
        roomsRepositoryProvider.overrideWithValue(_FakeRoomsRepo()),
        currentUserProvider.overrideWithValue(
          UserModel(
            id: 7,
            orgId: 1,
            login: 'ivan',
            role: role,
            teacherName: 'Иван',
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(body: RoomsTodayCard()),
      ),
    );

void main() {
  testWidgets('teacher sees today\'s rooms', (tester) async {
    await tester.pumpWidget(_wrap(role: 'TEACHER'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('МОИ КАБИНЕТЫ СЕГОДНЯ'), findsOneWidget);
    expect(find.text('Зал A'), findsOneWidget);
    expect(find.textContaining('10:00'), findsWidgets);
  });

  testWidgets('non-teacher sees nothing', (tester) async {
    await tester.pumpWidget(_wrap(role: 'ADMIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('МОИ КАБИНЕТЫ СЕГОДНЯ'), findsNothing);
  });
}
