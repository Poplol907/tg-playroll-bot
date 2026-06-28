import 'dart:convert';
import 'dart:typed_data';

import 'package:cosmo_studio/features/admin/data/rates_repository.dart';
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
  late RatesRepository repo;

  setUp(() {
    adapter = _FakeAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    repo = RatesRepository(dio);
  });

  test('getDefaultRate parses default_rate from GET response', () async {
    adapter.onRequest = (_) => {'default_rate': 75000};

    final rate = await repo.getDefaultRate(42);

    expect(rate, 75000);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/rates/teacher/42');
    expect(adapter.requests.single.method, 'GET');
  });

  test('getDefaultRate returns 0 when default_rate is absent', () async {
    adapter.onRequest = (_) => <String, dynamic>{};

    final rate = await repo.getDefaultRate(42);

    expect(rate, 0);
  });

  test('setDefaultRate POSTs rate_per_lesson and effective_from = today',
      () async {
    await repo.setDefaultRate(7, 60000);

    expect(adapter.requests, hasLength(1));
    final req = adapter.requests.single;
    expect(req.method, 'POST');
    expect(req.path, '/rates/teacher/7');

    final body = req.data as Map;
    expect(body['teacher_user_id'], 7);
    expect(body['instrument_id'], null);
    expect(body['is_foreign'], false);
    expect(body['rate_per_lesson'], 60000);

    final today = DateTime.now();
    final expectedYmd =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    expect(body['effective_from'], expectedYmd);
  });
}
