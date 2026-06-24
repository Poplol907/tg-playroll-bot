import 'package:cosmo_studio/features/calendar/data/calendar_repository.dart';
import 'package:cosmo_studio/features/calendar/presentation/providers/calendar_provider.dart';
import 'package:cosmo_studio/shared/models/lesson.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingRepo extends CalendarRepository {
  _RecordingRepo() : super(Dio());
  final calls = <({String monthYear, int? teacherId})>[];

  @override
  Future<List<LessonModel>> getLessons({
    required String monthYear,
    int? teacherId,
  }) async {
    calls.add((monthYear: monthYear, teacherId: teacherId));
    return const [];
  }
}

void main() {
  test('lessonsProvider keeps a separate cache entry per teacher context',
      () async {
    final repo = _RecordingRepo();
    final container = ProviderContainer(
      overrides: [calendarRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    // Admin (no view-as) and teacher 7 are distinct keys → two fetches.
    await container
        .read(lessonsProvider((monthYear: '2026-06', teacherId: null)).future);
    await container
        .read(lessonsProvider((monthYear: '2026-06', teacherId: 7)).future);
    // Re-reading teacher 7 is served from cache → no third fetch.
    await container
        .read(lessonsProvider((monthYear: '2026-06', teacherId: 7)).future);

    expect(repo.calls, const [
      (monthYear: '2026-06', teacherId: null),
      (monthYear: '2026-06', teacherId: 7),
    ]);
  });
}
