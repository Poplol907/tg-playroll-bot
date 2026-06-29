import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/presentation/widgets/room_board_grid.dart';

void main() {
  testWidgets('renders a tile for each block with teacher + time label',
      (tester) async {
    final rooms = [
      const Room(id: 1, name: 'Зал A', sortOrder: 0, isActive: true),
    ];
    final blocks = [
      const ResolvedRoomBlock(
        id: 10,
        roomId: 1,
        roomName: 'Зал A',
        teacherUserId: 3,
        teacherName: 'Иван',
        startTime: '09:00',
        endTime: '09:45',
        isRecurring: true,
      ),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: RoomBoardGrid(
          rooms: rooms,
          blocks: blocks,
          conflictIds: const {},
          onEmptyTap: (_, __) {},
          onBlockTap: (_) {},
        ),
      ),
    ));
    expect(find.text('Иван'), findsOneWidget);
    expect(find.textContaining('09:00'), findsWidgets);
    expect(find.text('Зал A'), findsWidgets);
  });

  testWidgets('renders a column for every room (supports many rooms)',
      (tester) async {
    final rooms = [
      for (var i = 1; i <= 6; i++)
        Room(id: i, name: 'Зал $i', sortOrder: i, isActive: true),
    ];
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: RoomBoardGrid(
          rooms: rooms,
          blocks: const [],
          conflictIds: const {},
          onEmptyTap: (_, __) {},
          onBlockTap: (_) {},
        ),
      ),
    ));
    for (var i = 1; i <= 6; i++) {
      expect(find.text('Зал $i'), findsOneWidget);
    }
  });
}
