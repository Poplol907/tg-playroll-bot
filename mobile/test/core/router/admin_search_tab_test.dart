import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/screens/search_screen.dart';
import 'package:cosmo_studio/shared/widgets/nebula_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('SearchScreen shows the Педагоги/Ученики segmented control',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          orgUsersProvider.overrideWith((ref) async => const []),
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
    await tester.pump();

    expect(find.byType(NebulaSegmentedControl), findsOneWidget);
    expect(find.text('Педагоги'), findsWidgets);
    expect(find.text('Ученики'), findsWidgets);
  });
}
