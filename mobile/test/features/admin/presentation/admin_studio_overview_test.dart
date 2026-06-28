import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Студия shows the stats overview and no teacher search field',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studioStatsProvider.overrideWith((ref) async => const StudioStats(
                month: '2026-06',
                totalLessonsDone: 0,
                totalLessonsMissed: 0,
                totalLessonsCancelled: 0,
                totalLessonsScheduled: 0,
                activeStudents: 0,
                activeTeachers: 0,
                teachers: [],
              )),
          orgUsersProvider.overrideWith((ref) async => <OrgUser>[]),
        ],
        child: const MaterialApp(home: AdminScreen()),
      ),
    );
    // Resolve the FutureProviders so the stats card renders (not the loader).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // Stats overview is present.
    expect(find.text('СТАТИСТИКА СТУДИИ'), findsOneWidget);
    // The teacher search field + list moved to the Поиск tab — gone from Студия.
    expect(find.text('Поиск по имени или логину...'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
