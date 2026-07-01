import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/admin/data/admin_repository.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/data/rooms_repository.dart';
import 'package:cosmo_studio/features/rooms/presentation/widgets/assign_block_sheet.dart';

void main() {
  testWidgets('assign sheet offers room, weekday and teacher pickers',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        roomsProvider.overrideWith((ref) async => const [
              Room(id: 1, name: 'Зал A', sortOrder: 0, isActive: true),
              Room(id: 2, name: 'Архивный', sortOrder: 1, isActive: false),
            ]),
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
          body: AssignBlockSheet(weekStart: DateTime(2026, 6, 29)),
        ),
      ),
    ));
    await tester.pump(); // resolve rooms + users futures

    expect(find.text('Назначить кабинет'), findsWidgets);
    // Only the active room is offered.
    expect(find.text('Зал A'), findsOneWidget);
    expect(find.text('Архивный'), findsNothing);
    // Weekday picker present.
    expect(find.text('Пн'), findsOneWidget);
    expect(find.text('Вс'), findsOneWidget);
    // Only the TEACHER is offered, not the admin.
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Админ'), findsNothing);
  });
}
