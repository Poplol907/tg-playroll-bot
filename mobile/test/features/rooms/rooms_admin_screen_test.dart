import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/data/rooms_repository.dart';
import 'package:cosmo_studio/features/rooms/presentation/screens/rooms_admin_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRoomsRepo extends RoomsRepository {
  _FakeRoomsRepo() : super(Dio());
  @override
  Future<List<Room>> getRooms({bool includeInactive = false}) async => const [
        Room(id: 1, name: 'Зал A', sortOrder: 0, isActive: true),
        Room(id: 2, name: 'Зал B', sortOrder: 1, isActive: true),
      ];
}

void main() {
  testWidgets('rooms admin lists rooms and offers an add action',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomsRepositoryProvider.overrideWithValue(_FakeRoomsRepo()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const RoomsAdminScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Зал A'), findsOneWidget);
    expect(find.text('Зал B'), findsOneWidget);
    expect(find.byTooltip('Добавить кабинет'), findsOneWidget);
  });
}
