import 'dart:async';
import 'dart:typed_data';

import 'package:cosmo_studio/core/network/api_client.dart';
import 'package:cosmo_studio/features/admin/presentation/providers/view_as_teacher_provider.dart';
import 'package:cosmo_studio/features/salary/presentation/providers/salary_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rates provider loads selected teacher rates in admin view-as mode',
      () async {
    final adapter = _RecordingAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter;

    final container = ProviderContainer(
      overrides: [
        dioProvider.overrideWithValue(dio),
        viewAsTeacherProvider.overrideWith((ref) {
          return const ViewAsTeacher(id: 42, displayName: 'Люсине');
        }),
      ],
    );
    addTearDown(container.dispose);

    final rates = await container.read(ratesProvider.future);

    expect(adapter.requests, ['/rates/teacher/42']);
    expect(rates, hasLength(1));
    expect(rates.single.ratePerLesson, 120000);
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options.path);
    return ResponseBody.fromString(
      '''
      {
        "teacher_user_id": 42,
        "teacher_name": "Люсине",
        "default_rate": 100000,
        "rates": [
          {
            "id": 1,
            "teacher_user_id": 42,
            "instrument_id": null,
            "instrument_name": null,
            "is_foreign": true,
            "rate_per_lesson": 120000,
            "effective_from": "2026-05-01",
            "note": "EN"
          }
        ]
      }
      ''',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
