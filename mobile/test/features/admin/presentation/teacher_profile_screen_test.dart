import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/admin/presentation/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets(
      'tapping a teacher opens a full-screen profile (not a Dialog) with the '
      'key sections and actions', (tester) async {
    const user = OrgUser(
      id: 7,
      login: 'anya',
      role: 'TEACHER',
      teacherName: 'Аня Петрова',
      hasPassword: true,
    );
    const stats = TeacherStats(
      teacherId: 7,
      teacherName: 'Аня Петрова',
      lessonsDone: 12,
      lessonsMissed: 2,
      lessonsCancelledMakeup: 1,
      lessonsDebt: 0,
      totalAmount: 48000,
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TeacherProfileEntry.button(
                context: context,
                user: user,
                stats: stats,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-profile'));
    // NOT pumpAndSettle: the app background (AppBackgroundHost) runs an ambient
    // animation that never settles. Pump once to start the push, then advance
    // past the SpacePageRoute transition with a fixed duration.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // It is a pushed screen, not a Dialog.
    expect(find.byType(Dialog), findsNothing);
    // Key content + actions are present.
    expect(find.text('Аня Петрова'), findsWidgets);
    expect(find.text('К выплате'), findsOneWidget);
    expect(find.textContaining('48'), findsWidgets); // 48 000 сум
    expect(find.text('Открыть как педагог'), findsOneWidget);
    expect(find.text('Удалить навсегда'), findsOneWidget);
  });
}
