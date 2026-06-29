import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'room_models.dart';

/// Admin-side room + room-block (classroom scheduling) access.
///
/// Mirrors the contract in
/// `docs/superpowers/specs/2026-06-25-track2-rooms-spec.md`.
class RoomsRepository {
  final Dio _dio;
  RoomsRepository(this._dio);

  /// Lists the studio's rooms, ordered by `sort_order` server-side.
  Future<List<Room>> getRooms({bool includeInactive = false}) async {
    final r = await _dio.get('/rooms', queryParameters: {
      'include_inactive': includeInactive,
    });
    final list = (r.data as List?) ?? const [];
    return list
        .map((e) => Room.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new room with the given name.
  Future<Room> createRoom(String name) async {
    final r = await _dio.post('/rooms', data: {'name': name});
    return Room.fromJson(r.data as Map<String, dynamic>);
  }

  /// Updates a room's name, sort order, and/or active flag. Only non-null
  /// fields are sent.
  Future<Room> updateRoom(
    int id, {
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (sortOrder != null) body['sort_order'] = sortOrder;
    if (isActive != null) body['is_active'] = isActive;
    final r = await _dio.patch('/rooms/$id', data: body);
    return Room.fromJson(r.data as Map<String, dynamic>);
  }

  /// Hard-deletes a room (cascades to its room blocks server-side).
  Future<void> deleteRoom(int id) async {
    await _dio.delete('/rooms/$id');
  }

  /// Resolved room blocks for a given date — recurring blocks matching that
  /// weekday (minus cancellation exceptions) plus one-offs for that date.
  Future<List<ResolvedRoomBlock>> getBlocksForDate(
    String dateYmd, {
    int? teacherId,
  }) async {
    final query = <String, dynamic>{'date': dateYmd};
    if (teacherId != null) query['teacher_id'] = teacherId;
    final r = await _dio.get('/room-blocks', queryParameters: query);
    final list = (r.data as List?) ?? const [];
    return list
        .map((e) => ResolvedRoomBlock.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Creates a room block — either recurring (set [weekday]) or a one-off
  /// (set [specificDate]). Exactly one of the two must be non-null.
  Future<RoomBlock> createBlock({
    required int roomId,
    required int teacherUserId,
    required String startTime,
    required String endTime,
    int? weekday,
    String? specificDate,
    String? note,
  }) async {
    assert((weekday == null) != (specificDate == null),
        'Exactly one of weekday/specificDate must be set');
    final r = await _dio.post('/room-blocks', data: {
      'room_id': roomId,
      'teacher_user_id': teacherUserId,
      'start_time': startTime,
      'end_time': endTime,
      'weekday': weekday,
      'specific_date': specificDate,
      'note': note,
    });
    return RoomBlock.fromJson(r.data as Map<String, dynamic>);
  }

  /// Deletes a room block (its exceptions cascade server-side).
  Future<void> deleteBlock(int id) async {
    await _dio.delete('/room-blocks/$id');
  }

  /// Cancels a recurring block on a specific date (adds an exception row).
  /// Idempotent server-side.
  Future<void> cancelBlock(int id, String dateYmd) async {
    await _dio.post('/room-blocks/$id/cancel', data: {'date': dateYmd});
  }

  /// Removes a cancellation exception (un-cancels a recurring block on that
  /// date).
  Future<void> uncancelBlock(int id, String dateYmd) async {
    await _dio.delete('/room-blocks/$id/cancel', queryParameters: {
      'date': dateYmd,
    });
  }
}

final roomsRepositoryProvider = Provider<RoomsRepository>(
  (ref) => RoomsRepository(ref.watch(dioProvider)),
);

/// All active rooms, ordered by `sort_order`.
final roomsProvider = FutureProvider<List<Room>>((ref) async {
  return ref.watch(roomsRepositoryProvider).getRooms();
});

/// Resolved room blocks for a given date, optionally filtered by teacher.
final roomBlocksForDateProvider = FutureProvider.family<List<ResolvedRoomBlock>,
    ({String date, int? teacherId})>((ref, args) async {
  return ref
      .watch(roomsRepositoryProvider)
      .getBlocksForDate(args.date, teacherId: args.teacherId);
});
