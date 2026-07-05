import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Правило safe-зон (см. CLAUDE.md): экраны ВНУТРИ AppShell живут под
  // SafeArea(top:false) — верхний инсет и month-остров резервирует сам шелл.
  // Любой другой экран/шит обязан занимать верхнюю safe-зону сам, иначе его
  // контент уезжает под Dynamic Island. Этот тест не даёт «top: false»
  // расползтись за пределы shell-роутов.
  test('SafeArea(top:false) is allowed only in shell-hosted screens', () {
    const shellScreens = {
      'lib/features/admin/presentation/screens/admin_screen.dart',
      'lib/features/admin/presentation/screens/search_screen.dart',
      'lib/features/calendar/presentation/screens/calendar_screen.dart',
      'lib/features/salary/presentation/screens/salary_screen.dart',
      'lib/features/settings/presentation/screens/settings_screen.dart',
      'lib/features/students/presentation/screens/students_screen.dart',
    };
    final pattern = RegExp(r'SafeArea\(\s*(?://[^\n]*\n\s*)?top:\s*false');
    final offenders = <String>[];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      if (shellScreens.contains(file.path)) continue;
      if (pattern.hasMatch(file.readAsStringSync())) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Экран вне AppShell обязан сам обрабатывать верхнюю safe-зону '
          '(SafeArea top:true). top:false разрешён только shell-роутам, '
          'за которые верхний резерв делает шелл.',
    );
  });
}
