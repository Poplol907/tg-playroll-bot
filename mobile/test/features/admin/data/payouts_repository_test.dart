import 'dart:convert';
import 'dart:typed_data';

import 'package:cosmo_studio/features/admin/data/payouts_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake [HttpClientAdapter] that records requests and returns a canned
/// response, avoiding any real network I/O in the test.
class _FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  dynamic Function(RequestOptions options)? onRequest;

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
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

void main() {
  late _FakeAdapter adapter;
  late Dio dio;
  late PayoutsRepository repo;

  setUp(() {
    adapter = _FakeAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    repo = PayoutsRepository(dio);
  });

  test('listPayouts parses the payouts from a GET list response', () async {
    adapter.onRequest = (_) => [
          {'id': 1, 'teacher_user_id': 7, 'month_year': '2026-06', 'amount': 10000, 'paid_at': '2026-06-01', 'note': null},
          {'id': 2, 'teacher_user_id': 7, 'month_year': '2026-06', 'amount': 5000, 'paid_at': '2026-06-15', 'note': null},
        ];

    final list = await repo.listPayouts(7, '2026-06');

    expect(list, hasLength(2));
    expect(list.first.id, 1);
    expect(list.first.amount, 10000);
    expect(list.first.paidAt, DateTime(2026, 6, 1));
    final req = adapter.requests.single;
    expect(req.method, 'GET');
    expect(req.path, '/payouts');
    expect(req.queryParameters['month_year'], '2026-06');
    expect(req.queryParameters['teacher_id'], 7);
  });

  test('listPayouts returns empty when the list is empty', () async {
    adapter.onRequest = (_) => [];

    final list = await repo.listPayouts(7, '2026-06');

    expect(list, isEmpty);
  });

  test('addPayout POSTs amount, paid_at, teacher_user_id, month_year',
      () async {
    await repo.addPayout(
      teacherId: 7,
      monthYear: '2026-06',
      amount: 12000,
      paidAt: DateTime(2026, 6, 29),
    );

    expect(adapter.requests, hasLength(1));
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/payouts');

    final body = req.data as Map;
    expect(body['teacher_user_id'], 7);
    expect(body['month_year'], '2026-06');
    expect(body['amount'], 12000);
    expect(body['paid_at'], '2026-06-29');
    expect(body['note'], null);
  });

  test('updatePayout PATCHes amount and paid_at', () async {
    await repo.updatePayout(5, amount: 9000, paidAt: DateTime(2026, 6, 20));

    final req = adapter.requests.single;
    expect(req.method, 'PATCH');
    expect(req.path, '/payouts/5');
    final body = req.data as Map;
    expect(body['amount'], 9000);
    expect(body['paid_at'], '2026-06-20');
  });

  test('deletePayout DELETEs the payout by id', () async {
    await repo.deletePayout(5);

    final req = adapter.requests.single;
    expect(req.method, 'DELETE');
    expect(req.path, '/payouts/5');
  });
}
