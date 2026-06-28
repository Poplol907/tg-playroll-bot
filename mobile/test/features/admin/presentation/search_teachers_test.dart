import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/screens/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Педагоги segment lists teachers and filters out admins',
      (tester) async {
    const teacher = OrgUser(
      id: 7,
      login: 'anya',
      role: 'TEACHER',
      teacherName: 'Аня Петрова',
      hasPassword: true,
    );
    const admin = OrgUser(
      id: 1,
      login: 'boss',
      role: 'ADMIN',
      hasPassword: true,
    );
    const stats = StudioStats(
      month: '2026-06',
      totalLessonsDone: 0,
      totalLessonsMissed: 0,
      totalLessonsCancelled: 0,
      totalLessonsScheduled: 0,
      activeStudents: 0,
      activeTeachers: 0,
      teachers: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orgUsersProvider.overrideWith((ref) async => [teacher, admin]),
          studioStatsProvider.overrideWith((ref) async => stats),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Аня Петрова'), findsWidgets);
    expect(find.text('boss'), findsNothing);
  });
}
