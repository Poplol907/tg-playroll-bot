import 'dart:async';
import 'dart:typed_data';

import 'package:cosmo_studio/core/network/api_client.dart';
import 'package:cosmo_studio/features/admin/presentation/providers/view_as_teacher_provider.dart';
import 'package:cosmo_studio/features/students/presentation/providers/student_lessons_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('student detail providers pass teacher_id in admin view-as mode',
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

    await container.read(studentLessonsProvider(7).future);
    await container.read(studentSubscriptionsProvider(7).future);

    expect(adapter.requests, hasLength(2));
    expect(adapter.requests[0].path, '/lessons');
    expect(adapter.requests[0].queryParameters, {
      'student_id': 7,
      'teacher_id': 42,
    });
    expect(adapter.requests[1].path, '/subscriptions');
    expect(adapter.requests[1].queryParameters, {
      'student_id': 7,
      'teacher_id': 42,
    });
  });
}

class _RecordedRequest {
  final String path;
  final Map<String, dynamic> queryParameters;

  const _RecordedRequest({
    required this.path,
    required this.queryParameters,
  });
}

class _RecordingAdapter implements HttpClientAdapter {
  final requests = <_RecordedRequest>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(_RecordedRequest(
      path: options.path,
      queryParameters: Map<String, dynamic>.from(options.queryParameters),
    ));
    return ResponseBody.fromString(
      '[]',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
