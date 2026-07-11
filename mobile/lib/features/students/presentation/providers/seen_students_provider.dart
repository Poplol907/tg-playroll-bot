import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/app_storage.dart';

/// Which students the user has already opened.
///
/// The "НОВЫЙ" badge marks a recently-added student, but must clear once its
/// card has actually been viewed — otherwise it lingered for the full 7 days
/// regardless of whether the user ever opened the student. Persisted via
/// [AppStorage] so it survives restarts.
class SeenStudentsNotifier extends Notifier<Set<int>> {
  static const _key = 'seen_student_ids';

  @override
  Set<int> build() {
    _load();
    return <int>{};
  }

  Future<void> _load() async {
    final raw = await AppStorage.instance.read(_key);
    if (raw == null || raw.isEmpty) return;
    final ids = raw.split(',').map(int.tryParse).whereType<int>().toSet();
    if (ids.isNotEmpty) state = ids;
  }

  /// Mark a student as seen (idempotent) and persist.
  Future<void> markSeen(int studentId) async {
    if (state.contains(studentId)) return;
    state = {...state, studentId};
    await AppStorage.instance.write(_key, state.join(','));
  }
}

final seenStudentsProvider =
    NotifierProvider<SeenStudentsNotifier, Set<int>>(SeenStudentsNotifier.new);
