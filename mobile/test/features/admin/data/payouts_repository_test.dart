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

  test('getPaidSum sums the amounts from a GET list response', () async {
    adapter.onRequest = (_) => [
          {'id': 1, 'teacher_user_id': 7, 'month_year': '2026-06', 'amount': 10000, 'paid_at': '2026-06-01', 'note': null},
          {'id': 2, 'teacher_user_id': 7, 'month_year': '2026-06', 'amount': 5000, 'paid_at': '2026-06-15', 'note': null},
        ];

    final sum = await repo.getPaidSum(7, '2026-06');

    expect(sum, 15000);
    expect(adapter.requests, hasLength(1));
    final req = adapter.requests.single;
    expect(req.method, 'GET');
    expect(req.path, '/payouts');
    expect(req.queryParameters['month_year'], '2026-06');
    expect(req.queryParameters['teacher_id'], 7);
  });

  test('getPaidSum returns 0 when the list is empty', () async {
    adapter.onRequest = (_) => [];

    final sum = await repo.getPaidSum(7, '2026-06');

    expect(sum, 0);
  });

  test('addPayout POSTs amount, paid_at = today, teacher_user_id, month_year',
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
}
