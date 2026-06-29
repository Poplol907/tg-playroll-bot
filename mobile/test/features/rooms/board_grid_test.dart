import 'package:flutter_test/flutter_test.dart';
import 'package:cosmo_studio/features/rooms/presentation/providers/room_board_providers.dart';

void main() {
  test('slotCount covers 09:00–21:00 in 45-min slots', () {
    expect(BoardGrid.slotCount, 16); // (1260-540)/45 = 16
  });

  test('gridHeight = slotCount * slotHeight', () {
    expect(BoardGrid.gridHeight, BoardGrid.slotCount * BoardGrid.slotHeight);
  });

  test('topFor maps start of day to 0 and one slot down to slotHeight', () {
    expect(BoardGrid.topFor(BoardGrid.startMinutes), 0);
    expect(BoardGrid.topFor(BoardGrid.startMinutes + BoardGrid.slotMinutes),
        BoardGrid.slotHeight);
  });

  test('contractWeekday converts Dart weekday (Mon=1..Sun=7) to contract (Mon=0..Sun=6)', () {
    expect(BoardGrid.contractWeekday(DateTime(2026, 6, 29)), 0); // Monday
    expect(BoardGrid.contractWeekday(DateTime(2026, 7, 5)), 6);  // Sunday
  });
}
