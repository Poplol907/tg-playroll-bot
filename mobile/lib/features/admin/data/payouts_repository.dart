import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Admin-side partial-payout tracking for a teacher's monthly pay.
class PayoutsRepository {
  final Dio _dio;
  PayoutsRepository(this._dio);

  /// Sum of all recorded payout amounts for a teacher in a given month.
  /// Returns 0 if no payouts are recorded.
  Future<int> getPaidSum(int teacherId, String monthYear) async {
    final r = await _dio.get('/payouts', queryParameters: {
      'month_year': monthYear,
      'teacher_id': teacherId,
    });
    final list = (r.data as List?) ?? const [];
    return list.fold<int>(
        0, (sum, item) => sum + ((item['amount'] as int?) ?? 0));
  }

  /// Records a new partial payment toward a teacher's monthly total.
  Future<void> addPayout({
    required int teacherId,
    required String monthYear,
    required int amount,
    required DateTime paidAt,
  }) async {
    final ymd =
        '${paidAt.year.toString().padLeft(4, '0')}-${paidAt.month.toString().padLeft(2, '0')}-${paidAt.day.toString().padLeft(2, '0')}';
    await _dio.post('/payouts', data: {
      'teacher_user_id': teacherId,
      'month_year': monthYear,
      'amount': amount,
      'paid_at': ymd,
      'note': null,
    });
  }
}

final payoutsRepositoryProvider = Provider<PayoutsRepository>(
  (ref) => PayoutsRepository(ref.watch(dioProvider)),
);

/// Sum of payouts paid to a teacher for a given month (family by
/// teacherId + monthYear).
final teacherPaidProvider = FutureProvider.family<int,
    ({int teacherId, String monthYear})>((ref, args) async {
  return ref
      .watch(payoutsRepositoryProvider)
      .getPaidSum(args.teacherId, args.monthYear);
});
