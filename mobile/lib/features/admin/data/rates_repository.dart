import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Текущая ставка педагога: базовая + (опционально) иностранный тариф.
class CurrentRates {
  final int base;
  final int? foreign;
  const CurrentRates({required this.base, this.foreign});

  factory CurrentRates.fromJson(Map<String, dynamic> j) => CurrentRates(
        base: (j['rate_per_lesson'] as int?) ?? 0,
        foreign: j['foreign_rate_per_lesson'] as int?,
      );
}

/// Admin-side teacher per-lesson rate access.
class RatesRepository {
  final Dio _dio;
  RatesRepository(this._dio);

  /// Current base + foreign per-lesson rate for a teacher.
  Future<CurrentRates> getCurrentRates(int teacherId) async {
    final r = await _dio.get('/rates/teacher/$teacherId/current');
    return CurrentRates.fromJson(r.data as Map<String, dynamic>);
  }

  /// Sets the teacher's current rate (base + optional foreign). No effective
  /// date — the server collapses history into a single row per tier.
  /// [foreignRate] null clears the foreign tariff.
  Future<void> setCurrentRates(
    int teacherId, {
    required int baseRate,
    int? foreignRate,
  }) async {
    await _dio.put('/rates/teacher/$teacherId/current', data: {
      'rate_per_lesson': baseRate,
      'foreign_rate_per_lesson': foreignRate,
    });
  }
}

final ratesRepositoryProvider = Provider<RatesRepository>(
  (ref) => RatesRepository(ref.watch(dioProvider)),
);

/// Current base + foreign rate for a teacher (family by teacher id).
final teacherCurrentRatesProvider =
    FutureProvider.family<CurrentRates, int>((ref, teacherId) async {
  return ref.watch(ratesRepositoryProvider).getCurrentRates(teacherId);
});
