import 'dart:convert';
import 'dart:typed_data';

import 'package:cosmo_studio/features/rooms/data/rooms_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake [HttpClientAdapter] that records requests and returns a canned
/// response, avoiding any real network I/O in the test.
class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  dynamic Function(RequestOptions options)? onRequest;
  int statusCode = 200;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final data = onRequest?.call(options) ?? {};
    final bytes = utf8.encode(jsonEncode(data));
    return ResponseBody.fromBytes(
      bytes,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _FakeAdapter adapter;
  late Dio dio;
  late RoomsRepository repo;

  setUp(() {
    adapter = _FakeAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    repo = RoomsRepository(dio);
  });

  test('getRooms parses RoomOut list and sends include_inactive query',
      () async {
    adapter.onRequest = (_) => [
          {'id': 1, 'name': 'Room A', 'sort_order': 0, 'is_active': true},
          {'id': 2, 'name': 'Room B', 'sort_order': 1, 'is_active': false},
        ];

    final rooms = await repo.getRooms(includeInactive: true);

    expect(rooms, hasLength(2));
    expect(rooms[0].id, 1);
    expect(rooms[0].name, 'Room A');
    expect(rooms[0].sortOrder, 0);
    expect(rooms[0].isActive, true);
    expect(rooms[1].isActive, false);

    final req = adapter.requests.single;
    expect(req.method, 'GET');
    expect(req.path, '/rooms');
    expect(req.queryParameters['include_inactive'], true);
  });

  test('getRooms defaults include_inactive to false', () async {
    adapter.onRequest = (_) => [];

    await repo.getRooms();

    final req = adapter.requests.single;
    expect(req.queryParameters['include_inactive'], false);
  });

  test('createRoom POSTs name and parses RoomOut', () async {
    adapter.onRequest = (_) =>
        {'id': 5, 'name': 'New Room', 'sort_order': 0, 'is_active': true};

    final room = await repo.createRoom('New Room');

    expect(room.id, 5);
    expect(room.name, 'New Room');
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/rooms');
    expect((req.data as Map)['name'], 'New Room');
  });

  test('updateRoom PATCHes only provided fields', () async {
    adapter.onRequest = (_) =>
        {'id': 5, 'name': 'Renamed', 'sort_order': 2, 'is_active': true};

    final room = await repo.updateRoom(5, name: 'Renamed', sortOrder: 2);

    expect(room.name, 'Renamed');
    final req = adapter.requests.single;
    expect(req.method, 'PATCH');
    expect(req.path, '/rooms/5');
    final body = req.data as Map;
    expect(body['name'], 'Renamed');
    expect(body['sort_order'], 2);
    expect(body.containsKey('is_active'), false);
  });

  test('deleteRoom sends DELETE to /rooms/{id}', () async {
    adapter.statusCode = 204;
    adapter.onRequest = (_) => null;

    await repo.deleteRoom(5);

    final req = adapter.requests.single;
    expect(req.method, 'DELETE');
    expect(req.path, '/rooms/5');
  });

  test(
      'getBlocksForDate parses ResolvedBlockOut list and sends date/teacher_id query',
      () async {
    adapter.onRequest = (_) => [
          {
            'id': 10,
            'room_id': 1,
            'room_name': 'Room A',
            'teacher_user_id': 7,
            'teacher_name': 'Anna',
            'start_time': '10:00',
            'end_time': '11:00',
            'note': null,
            'is_recurring': true,
            'specific_date': null,
            'weekday': 0,
          },
        ];

    final blocks =
        await repo.getBlocksForDate('2026-06-29', teacherId: 7);

    expect(blocks, hasLength(1));
    final b = blocks.single;
    expect(b.id, 10);
    expect(b.roomId, 1);
    expect(b.roomName, 'Room A');
    expect(b.teacherUserId, 7);
    expect(b.teacherName, 'Anna');
    expect(b.startTime, '10:00');
    expect(b.endTime, '11:00');
    expect(b.note, null);
    expect(b.isRecurring, true);
    expect(b.specificDate, null);
    expect(b.weekday, 0);

    final req = adapter.requests.single;
    expect(req.method, 'GET');
    expect(req.path, '/room-blocks');
    expect(req.queryParameters['date'], '2026-06-29');
    expect(req.queryParameters['teacher_id'], 7);
  });

  test('getBlocksForDate omits teacher_id when not provided', () async {
    adapter.onRequest = (_) => [];

    await repo.getBlocksForDate('2026-06-29');

    final req = adapter.requests.single;
    expect(req.queryParameters.containsKey('teacher_id'), false);
  });

  test('createBlock POSTs body with weekday set, specific_date null',
      () async {
    adapter.onRequest = (_) => {
          'id': 1,
          'room_id': 1,
          'teacher_user_id': 7,
          'weekday': 2,
          'specific_date': null,
          'start_time': '09:00',
          'end_time': '10:00',
          'note': null,
        };

    await repo.createBlock(
      roomId: 1,
      teacherUserId: 7,
      startTime: '09:00',
      endTime: '10:00',
      weekday: 2,
    );

    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/room-blocks');
    final body = req.data as Map;
    expect(body['room_id'], 1);
    expect(body['teacher_user_id'], 7);
    expect(body['start_time'], '09:00');
    expect(body['end_time'], '10:00');
    expect(body['weekday'], 2);
    expect(body['specific_date'], null);
    expect(body['note'], null);
  });

  test('createBlock POSTs body with specific_date set, weekday null',
      () async {
    adapter.onRequest = (_) => {
          'id': 1,
          'room_id': 1,
          'teacher_user_id': 7,
          'weekday': null,
          'specific_date': '2026-07-01',
          'start_time': '09:00',
          'end_time': '10:00',
          'note': 'one-off',
        };

    await repo.createBlock(
      roomId: 1,
      teacherUserId: 7,
      startTime: '09:00',
      endTime: '10:00',
      specificDate: '2026-07-01',
      note: 'one-off',
    );

    final req = adapter.requests.single;
    final body = req.data as Map;
    expect(body['weekday'], null);
    expect(body['specific_date'], '2026-07-01');
    expect(body['note'], 'one-off');
  });

  test('deleteBlock sends DELETE to /room-blocks/{id}', () async {
    adapter.statusCode = 204;
    adapter.onRequest = (_) => null;

    await repo.deleteBlock(10);

    final req = adapter.requests.single;
    expect(req.method, 'DELETE');
    expect(req.path, '/room-blocks/10');
  });

  test('cancelBlock POSTs {date} to /room-blocks/{id}/cancel', () async {
    await repo.cancelBlock(10, '2026-06-29');

    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/room-blocks/10/cancel');
    expect((req.data as Map)['date'], '2026-06-29');
  });

  test('uncancelBlock sends DELETE with date query', () async {
    adapter.statusCode = 204;
    adapter.onRequest = (_) => null;

    await repo.uncancelBlock(10, '2026-06-29');

    final req = adapter.requests.single;
    expect(req.method, 'DELETE');
    expect(req.path, '/room-blocks/10/cancel');
    expect(req.queryParameters['date'], '2026-06-29');
  });
}
