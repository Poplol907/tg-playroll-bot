import 'package:flutter/material.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../data/room_models.dart';
import '../providers/room_board_providers.dart';
import '../util/block_conflicts.dart';
import 'room_block_tile.dart';

/// Read-only day board grid: rooms as columns, 09:00–21:00 in 45-min slots
/// as rows. Renders a fixed time gutter on the left and a horizontally
/// scrollable row of room columns on the right.
class RoomBoardGrid extends StatelessWidget {
  final List<Room> rooms;
  final List<ResolvedRoomBlock> blocks;
  final Set<int> conflictIds;
  final void Function(int roomId, int startMinutes) onEmptyTap;
  final void Function(ResolvedRoomBlock block) onBlockTap;

  const RoomBoardGrid({
    super.key,
    required this.rooms,
    required this.blocks,
    required this.conflictIds,
    required this.onEmptyTap,
    required this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TimeGutter(),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final room in rooms)
                    _RoomColumn(
                      room: room,
                      blocks: blocks
                          .where((b) => b.roomId == room.id)
                          .toList(),
                      conflictIds: conflictIds,
                      onEmptyTap: onEmptyTap,
                      onBlockTap: onBlockTap,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeGutter extends StatelessWidget {
  const _TimeGutter();

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return SizedBox(
      width: BoardGrid.gutterWidth,
      child: Column(
        children: List.generate(BoardGrid.slotCount, (i) {
          final minutes = BoardGrid.startMinutes + i * BoardGrid.slotMinutes;
          final label =
              '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
          return SizedBox(
            height: BoardGrid.slotHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                label,
                style: type.labelS.copyWith(color: tokens.mutedText),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RoomColumn extends StatelessWidget {
  final Room room;
  final List<ResolvedRoomBlock> blocks;
  final Set<int> conflictIds;
  final void Function(int roomId, int startMinutes) onEmptyTap;
  final void Function(ResolvedRoomBlock block) onBlockTap;

  const _RoomColumn({
    required this.room,
    required this.blocks,
    required this.conflictIds,
    required this.onEmptyTap,
    required this.onBlockTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return SizedBox(
      width: BoardGrid.columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Text(
              room.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: type.titleS.copyWith(color: tokens.primaryText),
            ),
          ),
          SizedBox(
            height: BoardGrid.gridHeight,
            child: Stack(
              children: [
                for (var i = 0; i < BoardGrid.slotCount; i++)
                  Positioned(
                    top: i * BoardGrid.slotHeight,
                    left: 0,
                    right: 0,
                    height: BoardGrid.slotHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onEmptyTap(
                        room.id,
                        BoardGrid.startMinutes + i * BoardGrid.slotMinutes,
                      ),
                    ),
                  ),
                for (final block in blocks)
                  Positioned(
                    top: BoardGrid.topFor(hhmmToMinutes(block.startTime)),
                    left: 0,
                    right: 0,
                    height: (hhmmToMinutes(block.endTime) -
                            hhmmToMinutes(block.startTime)) /
                        BoardGrid.slotMinutes *
                        BoardGrid.slotHeight,
                    child: RoomBlockTile(
                      block: block,
                      isConflict: conflictIds.contains(block.id),
                      onTap: () => onBlockTap(block),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
