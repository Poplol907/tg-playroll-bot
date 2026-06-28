import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/screens/search_screen.dart';
import 'package:cosmo_studio/features/students/data/students_repository.dart';
import 'package:cosmo_studio/shared/models/student.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Ученики segment lists studio students and filters by query',
      (tester) async {
    final ivan = StudentModel(
      id: 1,
      orgId: 1,
      firstName: 'Иван',
      lastName: 'Иванов',
      status: 'ACTIVE',
      isForeign: false,
      createdAt: DateTime(2024, 1, 1),
    );
    final maria = StudentModel(
      id: 2,
      orgId: 1,
      firstName: 'Мария',
      lastName: 'Сидорова',
      status: 'ACTIVE',
      isForeign: false,
      createdAt: DateTime(2024, 1, 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentsProvider.overrideWith((ref) async => [ivan, maria]),
          orgUsersProvider.overrideWith((ref) async => []),
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
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Ученики'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Иван Иванов'), findsOneWidget);
    expect(find.text('Мария Сидорова'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Иван');
    await tester.pump();

    expect(find.text('Иван Иванов'), findsOneWidget);
    expect(find.text('Мария Сидорова'), findsNothing);
  });
}
