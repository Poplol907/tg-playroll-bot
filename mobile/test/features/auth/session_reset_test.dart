import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cosmo_studio/core/session/session_reset.dart';
import 'package:cosmo_studio/features/auth/presentation/providers/auth_provider.dart';
import 'package:cosmo_studio/features/rooms/data/room_models.dart';
import 'package:cosmo_studio/features/rooms/data/rooms_repository.dart';
import 'package:cosmo_studio/shared/models/user.dart';

/// Fake repo whose returned rooms can be swapped to mimic the backend
/// returning a different account's data once the auth token changes.
class _FakeRoomsRepo extends RoomsRepository {
  _FakeRoomsRepo() : super(Dio());
  List<Room> rooms = const [];
  @override
  Future<List<Room>> getRooms({bool includeInactive = false}) async => rooms;
}

final _testUserProvider = StateProvider<UserModel?>((ref) => null);

UserModel _user(int id, String login) =>
    UserModel(id: id, orgId: 1, login: login, role: 'TEACHER', teacherName: login);

void main() {
  testWidgets('switching account drops the previous user cached data',
      (tester) async {
    final fake = _FakeRoomsRepo()
      ..rooms = const [Room(id: 1, name: 'A-ROOM', sortOrder: 0, isActive: true)];

    final container = ProviderContainer(overrides: [
      roomsRepositoryProvider.overrideWithValue(fake),
      currentUserProvider.overrideWith((ref) => ref.watch(_testUserProvider)),
    ]);
    addTearDown(container.dispose);

    // Account A is logged in.
    container.read(_testUserProvider.notifier).state = _user(3, 'ali');

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SessionResetGate(child: _RoomsView())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('A-ROOM'), findsOneWidget);

    // Backend would now answer with account B's rooms.
    fake.rooms = const [Room(id: 2, name: 'B-ROOM', sortOrder: 0, isActive: true)];

    // Switch to account B.
    container.read(_testUserProvider.notifier).state = _user(4, 'lucile');
    await tester.pumpAndSettle();

    // The board must reflect B, never the cached A list.
    expect(find.text('B-ROOM'), findsOneWidget);
    expect(find.text('A-ROOM'), findsNothing);
  });
}

class _RoomsView extends ConsumerWidget {
  const _RoomsView();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rooms = ref.watch(roomsProvider);
    return Scaffold(
      body: Center(
        child: rooms.when(
          loading: () => const Text('...'),
          error: (e, _) => Text('err $e'),
          data: (list) => Text(list.isEmpty ? 'EMPTY' : list.first.name),
        ),
      ),
    );
  }
}
