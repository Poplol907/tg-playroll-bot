import 'package:flutter/material.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../data/room_models.dart';
import '../providers/room_board_providers.dart';
import '../util/block_conflicts.dart';
import 'room_block_tile.dart';

/// Height of the room-name column header. The time gutter reserves the same
/// height as a top spacer so its time labels line up with the column rows.
const double _headerHeight = 40;

/// The Day board: a fixed left time gutter (09:00–21:00, 45-min rows) and
/// horizontally scrollable room columns. Blocks are absolutely positioned
/// inside each column by their start/end time; blocks whose id is in
/// [conflictIds] are highlighted by [RoomBlockTile].
///
/// v1 keeps it simple: the whole board scrolls vertically (the time axis is
/// taller than the viewport) and room columns scroll horizontally. Sticky
/// headers are deliberately out of scope.
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final room in rooms)
                    _RoomColumn(
                      room: room,
                      blocks:
                          blocks.where((b) => b.roomId == room.id).toList(),
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

String _fmtTime(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

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
        children: [
          const SizedBox(height: _headerHeight),
          for (var i = 0; i < BoardGrid.slotCount; i++)
            SizedBox(
              height: BoardGrid.slotHeight,
              child: Padding(
                padding: const EdgeInsets.only(right: 6, top: 2),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Text(
                    _fmtTime(
                        BoardGrid.startMinutes + i * BoardGrid.slotMinutes),
                    style:
                        type.labelS.copyWith(color: tokens.mutedText).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
    final gridline = tokens.surfaceBorder.withValues(alpha: NebulaAlpha.mist);

    return SizedBox(
      width: BoardGrid.columnWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: _headerHeight,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: type.titleS.copyWith(color: tokens.primaryText),
                ),
              ),
            ),
          ),
          SizedBox(
            height: BoardGrid.gridHeight,
            child: Stack(
              children: [
                // Empty-slot hit cells + gridlines (behind the blocks).
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
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: gridline),
                            left: BorderSide(color: gridline),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Positioned teacher blocks (in front, so they win taps).
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
