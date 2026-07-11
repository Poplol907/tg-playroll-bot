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

  test('getCurrentRates parses base + foreign from GET /current', () async {
    adapter.onRequest = (_) =>
        {'rate_per_lesson': 75000, 'foreign_rate_per_lesson': 90000};

    final rates = await repo.getCurrentRates(42);

    expect(rates.base, 75000);
    expect(rates.foreign, 90000);
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.path, '/rates/teacher/42/current');
    expect(adapter.requests.single.method, 'GET');
  });

  test('getCurrentRates leaves foreign null when absent', () async {
    adapter.onRequest = (_) =>
        {'rate_per_lesson': 50000, 'foreign_rate_per_lesson': null};

    final rates = await repo.getCurrentRates(42);

    expect(rates.base, 50000);
    expect(rates.foreign, isNull);
  });

  test('setCurrentRates PUTs base + foreign to /current', () async {
    adapter.onRequest = (_) =>
        {'rate_per_lesson': 60000, 'foreign_rate_per_lesson': 80000};

    await repo.setCurrentRates(7, baseRate: 60000, foreignRate: 80000);

    expect(adapter.requests, hasLength(1));
    final req = adapter.requests.single;
    expect(req.method, 'PUT');
    expect(req.path, '/rates/teacher/7/current');

    final body = req.data as Map;
    expect(body['rate_per_lesson'], 60000);
    expect(body['foreign_rate_per_lesson'], 80000);
  });

  test('setCurrentRates sends null foreign to clear the foreign tariff',
      () async {
    adapter.onRequest = (_) =>
        {'rate_per_lesson': 60000, 'foreign_rate_per_lesson': null};

    await repo.setCurrentRates(7, baseRate: 60000);

    final body = adapter.requests.single.data as Map;
    expect(body['rate_per_lesson'], 60000);
    expect(body.containsKey('foreign_rate_per_lesson'), true);
    expect(body['foreign_rate_per_lesson'], null);
  });
}
