import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Admin-side teacher per-lesson rate access.
class RatesRepository {
  final Dio _dio;
  RatesRepository(this._dio);

  /// Current default (no-instrument) per-lesson rate for a teacher, in whole
  /// currency units. Returns 0 if none set.
  Future<int> getDefaultRate(int teacherId) async {
    final r = await _dio.get('/rates/teacher/$teacherId');
    return (r.data['default_rate'] as int?) ?? 0;
  }

  /// Sets a new default per-lesson rate effective today. History is preserved
  /// server-side.
  Future<void> setDefaultRate(int teacherId, int ratePerLesson) async {
    final today = DateTime.now();
    final ymd =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await _dio.post('/rates/teacher/$teacherId', data: {
      'teacher_user_id': teacherId,
      'instrument_id': null,
      'is_foreign': false,
      'rate_per_lesson': ratePerLesson,
      'effective_from': ymd,
    });
  }
}

final ratesRepositoryProvider = Provider<RatesRepository>(
  (ref) => RatesRepository(ref.watch(dioProvider)),
);

/// Current default rate for a teacher (family by teacher id).
final teacherDefaultRateProvider =
    FutureProvider.family<int, int>((ref, teacherId) async {
  return ref.watch(ratesRepositoryProvider).getDefaultRate(teacherId);
});
