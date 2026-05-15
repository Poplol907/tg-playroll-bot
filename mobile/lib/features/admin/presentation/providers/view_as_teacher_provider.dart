import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Контекст "просмотра как педагог" для админа.
///
/// Когда выставлен — все запросы (lessons, students, salary) должны
/// передавать `teacher_id`, а UI показывать данные этого педагога.
class ViewAsTeacher {
  final int id;
  final String displayName;

  const ViewAsTeacher({required this.id, required this.displayName});

  @override
  bool operator ==(Object other) =>
      other is ViewAsTeacher &&
      other.id == id &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, displayName);
}

/// `null` — обычный режим. Не-`null` — админ просматривает данные педагога.
final viewAsTeacherProvider =
    StateProvider<ViewAsTeacher?>((ref) => null);
