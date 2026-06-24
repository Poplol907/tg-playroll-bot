import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const screens = {
    'calendar':
        'lib/features/calendar/presentation/screens/calendar_screen.dart',
    'students':
        'lib/features/students/presentation/screens/students_screen.dart',
    'salary': 'lib/features/salary/presentation/screens/salary_screen.dart',
    'settings':
        'lib/features/settings/presentation/screens/settings_screen.dart',
    'admin': 'lib/features/admin/presentation/screens/admin_screen.dart',
  };

  test('all shell screens compose the canonical screen header', () {
    final offenders = <String>[];
    for (final entry in screens.entries) {
      final source = File(entry.value).readAsStringSync();
      if (!source.contains('AppScreenHeader(')) offenders.add(entry.key);
    }
    expect(offenders, isEmpty);
  });

  test('calendar no longer owns account logout chrome', () {
    final source = File(screens['calendar']!).readAsStringSync();
    expect(source, isNot(contains('_confirmLogout')));
    expect(source, isNot(contains('Icons.logout_rounded')));
  });

  test('students header uses scroll motion and list remains lazy', () {
    final source = File(screens['students']!).readAsStringSync();
    expect(source, isNot(contains('NebulaParallaxFrame')));
    expect(source, isNot(contains('ShaderMask(')));
    expect(source, contains('SliverList.builder('));
    expect(source, contains('if (i >= stagger) return card'));
  });

  test('settings remains the account logout destination', () {
    final source = File(screens['settings']!).readAsStringSync();
    expect(source, contains("label: 'Выйти из аккаунта'"));
    expect(source, contains('onTap: _logout'));
  });
}
