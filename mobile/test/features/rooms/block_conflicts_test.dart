import 'package:flutter_test/flutter_test.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/presentation/util/block_conflicts.dart';

ResolvedRoomBlock _b({
  required int id,
  required int roomId,
  required String start,
  required String end,
}) =>
    ResolvedRoomBlock(
      id: id,
      roomId: roomId,
      roomName: 'R$roomId',
      teacherUserId: 1,
      startTime: start,
      endTime: end,
      isRecurring: true,
    );

void main() {
  test('hhmmToMinutes parses HH:MM', () {
    expect(hhmmToMinutes('09:00'), 540);
    expect(hhmmToMinutes('09:45'), 585);
    expect(hhmmToMinutes('21:00'), 1260);
  });

  test('touching intervals in same room are NOT a conflict (half-open)', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '09:45'),
      _b(id: 2, roomId: 1, start: '09:45', end: '10:30'),
    ];
    expect(conflictingBlockIds(blocks), isEmpty);
  });

  test('overlapping intervals in same room flag both ids', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '10:00'),
      _b(id: 2, roomId: 1, start: '09:30', end: '10:30'),
    ];
    expect(conflictingBlockIds(blocks), {1, 2});
  });

  test('overlapping intervals in DIFFERENT rooms are not a conflict', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '10:00'),
      _b(id: 2, roomId: 2, start: '09:30', end: '10:30'),
    ];
    expect(conflictingBlockIds(blocks), isEmpty);
  });

  test('three mutually overlapping blocks all flagged', () {
    final blocks = [
      _b(id: 1, roomId: 1, start: '09:00', end: '11:00'),
      _b(id: 2, roomId: 1, start: '09:30', end: '10:00'),
      _b(id: 3, roomId: 1, start: '10:30', end: '11:30'),
    ];
    expect(conflictingBlockIds(blocks), {1, 2, 3});
  });
}
