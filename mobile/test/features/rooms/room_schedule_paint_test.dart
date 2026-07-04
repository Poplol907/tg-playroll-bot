import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/data/rooms_repository.dart';
import 'package:cosmo_studio/features/rooms/presentation/screens/room_schedule_screen.dart';
import 'package:cosmo_studio/shared/models/user.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class _FakeRoomsRepository extends RoomsRepository {
  _FakeRoomsRepository() : super(Dio());

  final List<Map<String, Object?>> createdBlocks = [];

  @override
  Future<List<ResolvedRoomBlock>> getBlocksForDate(
    String dateYmd, {
    int? teacherId,
  }) async =>
      const [];

  @override
  Future<RoomBlock> createBlock({
    required int roomId,
    required int teacherUserId,
    required String startTime,
    required String endTime,
    int? weekday,
    String? specificDate,
    String? note,
  }) async {
    createdBlocks.add({
      'roomId': roomId,
      'teacherUserId': teacherUserId,
      'startTime': startTime,
      'endTime': endTime,
      'weekday': weekday,
      'specificDate': specificDate,
    });
    return RoomBlock(
      id: createdBlocks.length,
      roomId: roomId,
      teacherUserId: teacherUserId,
      weekday: weekday,
      specificDate: specificDate,
      startTime: startTime,
      endTime: endTime,
      note: note,
    );
  }
}

void main() {
  group('mergePaintedSlots', () {
    test('merges contiguous slots of one teacher into one range', () {
      final ranges = mergePaintedSlots({
        (wd: 0, slot: 0): 7,
        (wd: 0, slot: 1): 7,
      });
      expect(ranges, hasLength(1));
      expect(ranges.single.weekday, 0);
      expect(ranges.single.teacherId, 7);
      expect(ranges.single.startMin, 9 * 60); // 09:00
      expect(ranges.single.endMin, 10 * 60 + 30); // 2×45мин → 10:30
    });

    test('splits on gaps, teacher change and weekday', () {
      final ranges = mergePaintedSlots({
        (wd: 0, slot: 0): 7,
        (wd: 0, slot: 2): 7, // разрыв
        (wd: 0, slot: 3): 8, // другой педагог
        (wd: 2, slot: 0): 7, // другой день
      });
      expect(ranges, hasLength(4));
    });
  });

  testWidgets(
      'paint mode: кисть → тап по ячейкам → сохранение батчем одним блоком',
      (tester) async {
    final fakeRepo = _FakeRoomsRepository();
    const room = Room(id: 5, name: 'Синий зал', sortOrder: 0, isActive: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomsRepositoryProvider.overrideWithValue(fakeRepo),
          currentUserProvider.overrideWithValue(
            const UserModel(id: 1, orgId: 1, login: 'admin', role: 'ADMIN'),
          ),
          orgUsersProvider.overrideWith((ref) async => const [
                OrgUser(
                  id: 7,
                  login: 'anya',
                  role: 'TEACHER',
                  teacherName: 'Аня Петрова',
                  hasPassword: true,
                ),
              ]),
        ],
        child: const MaterialApp(
          home: RoomScheduleScreen(room: room),
        ),
      ),
    );
    // Первый pump — загрузка блоков; фикс-даты не ждём через settle из-за
    // амбиентного фона.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Включаем режим редактирования.
    await tester.tap(find.byKey(const ValueKey('room-edit-toggle')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Редактирование'), findsOneWidget);

    // orgUsersProvider — FutureProvider: даём кадры на loading → data.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Выбираем кисть-педагога.
    await tester.tap(find.byKey(const ValueKey('brush-teacher-7')));
    await tester.pump(const Duration(milliseconds: 300));

    // Один свайп сверху вниз красит сразу линию: слоты 0..2 понедельника.
    final start = tester.getCenter(find.byKey(const ValueKey('cell-0-0')));
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('cell-0-1'))));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('cell-0-2'))));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Сохранить (3)'), findsOneWidget);

    // Тап-покраска тоже работает: стираем третий слот тапом по нему.
    await tester.tapAt(
        tester.getTopLeft(find.byKey(const ValueKey('pending-0-0'))) +
            const Offset(10, 2 * 40 + 10));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Сохранить (2)'), findsOneWidget);

    // Тап по закрашенному диапазону стирает один слот.
    final pending = find.byKey(const ValueKey('pending-0-0'));
    expect(pending, findsOneWidget);
    await tester.tapAt(tester.getTopLeft(pending) + const Offset(10, 10));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Сохранить (1)'), findsOneWidget);

    // Возвращаем второй слот и сохраняем.
    await tester.tap(find.byKey(const ValueKey('cell-0-0')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const ValueKey('paint-save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Один merged-блок 09:00–10:30, еженедельный (weekday задан).
    expect(fakeRepo.createdBlocks, hasLength(1));
    final call = fakeRepo.createdBlocks.single;
    expect(call['roomId'], 5);
    expect(call['teacherUserId'], 7);
    expect(call['startTime'], '09:00');
    expect(call['endTime'], '10:30');
    expect(call['weekday'], 0);
    expect(call['specificDate'], isNull);

    // Режим редактирования закрылся, тост об успехе показан.
    expect(find.text('Расписание'), findsOneWidget);
    expect(find.text('Расписание сохранено'), findsOneWidget);

    // Даём тосту закрыться, чтобы не осталось таймеров.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 400));
  });
}
