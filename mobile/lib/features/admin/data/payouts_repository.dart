import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

/// Одна зафиксированная выплата педагогу за месяц.
class PayoutModel {
  final int id;
  final int amount;
  final DateTime paidAt;
  final String? note;

  const PayoutModel({
    required this.id,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  factory PayoutModel.fromJson(Map<String, dynamic> j) => PayoutModel(
        id: j['id'] as int,
        amount: (j['amount'] as int?) ?? 0,
        paidAt: DateTime.parse(j['paid_at'] as String),
        note: j['note'] as String?,
      );
}

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Admin-side partial-payout tracking for a teacher's monthly pay.
class PayoutsRepository {
  final Dio _dio;
  PayoutsRepository(this._dio);

  /// All recorded payouts for a teacher in a month (server orders newest first).
  Future<List<PayoutModel>> listPayouts(int teacherId, String monthYear) async {
    final r = await _dio.get('/payouts', queryParameters: {
      'month_year': monthYear,
      'teacher_id': teacherId,
    });
    final list = (r.data as List?) ?? const [];
    return list
        .map((e) => PayoutModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Records a new partial payment toward a teacher's monthly total.
  Future<void> addPayout({
    required int teacherId,
    required String monthYear,
    required int amount,
    required DateTime paidAt,
  }) async {
    await _dio.post('/payouts', data: {
      'teacher_user_id': teacherId,
      'month_year': monthYear,
      'amount': amount,
      'paid_at': _ymd(paidAt),
      'note': null,
    });
  }

  /// Edits an existing payout (amount and/or date).
  Future<void> updatePayout(
    int payoutId, {
    int? amount,
    DateTime? paidAt,
  }) async {
    await _dio.patch('/payouts/$payoutId', data: {
      if (amount != null) 'amount': amount,
      if (paidAt != null) 'paid_at': _ymd(paidAt),
    });
  }

  /// Removes a payout.
  Future<void> deletePayout(int payoutId) async {
    await _dio.delete('/payouts/$payoutId');
  }
}

final payoutsRepositoryProvider = Provider<PayoutsRepository>(
  (ref) => PayoutsRepository(ref.watch(dioProvider)),
);

/// All payouts for a teacher in a month (family by teacherId + monthYear).
final teacherPayoutsProvider = FutureProvider.family<List<PayoutModel>,
    ({int teacherId, String monthYear})>((ref, args) async {
  return ref
      .watch(payoutsRepositoryProvider)
      .listPayouts(args.teacherId, args.monthYear);
});

/// Sum of payouts paid to a teacher for a month — derived from the list, so
/// invalidating [teacherPayoutsProvider] refreshes the total too.
final teacherPaidProvider = FutureProvider.family<int,
    ({int teacherId, String monthYear})>((ref, args) async {
  final list = await ref.watch(teacherPayoutsProvider(args).future);
  return list.fold<int>(0, (sum, p) => sum + p.amount);
});
