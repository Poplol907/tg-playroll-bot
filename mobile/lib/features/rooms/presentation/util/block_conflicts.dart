import '../../data/room_models.dart';

/// Converts a wire time string ("HH:MM") to minutes since midnight.
int hhmmToMinutes(String hhmm) {
  final parts = hhmm.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

/// True if two blocks share a room and their [start, end) intervals overlap.
bool blocksConflict(ResolvedRoomBlock a, ResolvedRoomBlock b) {
  if (a.id == b.id || a.roomId != b.roomId) return false;
  final aStart = hhmmToMinutes(a.startTime), aEnd = hhmmToMinutes(a.endTime);
  final bStart = hhmmToMinutes(b.startTime), bEnd = hhmmToMinutes(b.endTime);
  return aStart < bEnd && bStart < aEnd; // half-open: touching is OK
}

/// Ids of every block that overlaps at least one other block in its room.
Set<int> conflictingBlockIds(List<ResolvedRoomBlock> blocks) {
  final ids = <int>{};
  for (var i = 0; i < blocks.length; i++) {
    for (var j = i + 1; j < blocks.length; j++) {
      if (blocksConflict(blocks[i], blocks[j])) {
        ids..add(blocks[i].id)..add(blocks[j].id);
      }
    }
  }
  return ids;
}
