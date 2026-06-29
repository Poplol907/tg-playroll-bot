import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/rooms/presentation/widgets/assign_block_sheet.dart';

void main() {
  testWidgets('assign sheet shows the room, a teacher, and a save action',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        orgUsersProvider.overrideWith((ref) async => const [
              OrgUser(
                id: 1,
                login: 'ivan',
                role: 'TEACHER',
                teacherName: 'Иван',
                hasPassword: true,
              ),
              OrgUser(
                id: 2,
                login: 'boss',
                role: 'ADMIN',
                teacherName: 'Админ',
                hasPassword: true,
              ),
            ]),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: AssignBlockSheet(
            roomId: 1,
            roomName: 'Зал A',
            date: DateTime(2026, 6, 29),
            initialStartMinutes: 540,
          ),
        ),
      ),
    ));
    await tester.pump(); // resolve orgUsersProvider future

    // Room name appears in the title; "Назначить" appears in title + button.
    expect(find.textContaining('Зал A'), findsWidgets);
    expect(find.textContaining('Назначить'), findsWidgets);
    // Only the TEACHER is offered, not the admin.
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Админ'), findsNothing);
  });
}
