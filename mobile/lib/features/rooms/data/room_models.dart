/// A studio room used for board columns (`RoomOut` over the wire).
class Room {
  final int id;
  final String name;
  final int sortOrder;
  final bool isActive;

  const Room({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
  });

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as int,
        name: json['name'] as String,
        sortOrder: (json['sort_order'] as int?) ?? 0,
        isActive: (json['is_active'] as bool?) ?? true,
      );
}

/// A resolved room block for a specific date (`ResolvedBlockOut` over the
/// wire) — either a recurring weekly block or a one-off, already filtered
/// for cancellation exceptions by the backend.
class ResolvedRoomBlock {
  final int id;
  final int roomId;
  final String roomName;
  final int teacherUserId;
  final String? teacherName;
  final String startTime;
  final String endTime;
  final String? note;
  final bool isRecurring;
  final String? specificDate;
  final int? weekday;

  const ResolvedRoomBlock({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.teacherUserId,
    this.teacherName,
    required this.startTime,
    required this.endTime,
    this.note,
    required this.isRecurring,
    this.specificDate,
    this.weekday,
  });

  factory ResolvedRoomBlock.fromJson(Map<String, dynamic> json) =>
      ResolvedRoomBlock(
        id: json['id'] as int,
        roomId: json['room_id'] as int,
        roomName: json['room_name'] as String,
        teacherUserId: json['teacher_user_id'] as int,
        teacherName: json['teacher_name'] as String?,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        note: json['note'] as String?,
        isRecurring: (json['is_recurring'] as bool?) ?? false,
        specificDate: json['specific_date'] as String?,
        weekday: json['weekday'] as int?,
      );
}

/// The create/raw block response (`RoomBlockOut` over the wire) — the
/// un-resolved template row, returned by `POST /room-blocks`.
class RoomBlock {
  final int id;
  final int roomId;
  final int teacherUserId;
  final int? weekday;
  final String? specificDate;
  final String startTime;
  final String endTime;
  final String? note;

  const RoomBlock({
    required this.id,
    required this.roomId,
    required this.teacherUserId,
    this.weekday,
    this.specificDate,
    required this.startTime,
    required this.endTime,
    this.note,
  });

  factory RoomBlock.fromJson(Map<String, dynamic> json) => RoomBlock(
        id: json['id'] as int,
        roomId: json['room_id'] as int,
        teacherUserId: json['teacher_user_id'] as int,
        weekday: json['weekday'] as int?,
        specificDate: json['specific_date'] as String?,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        note: json['note'] as String?,
      );
}
