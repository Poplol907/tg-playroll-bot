import 'package:flutter/material.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../data/room_models.dart';
import '../util/teacher_color.dart';

/// A single scheduled block on the room board — teacher name + time range,
/// tinted with the teacher's deterministic color and highlighted when it
/// conflicts with another block in the same room.
class RoomBlockTile extends StatelessWidget {
  final ResolvedRoomBlock block;
  final bool isConflict;
  final VoidCallback? onTap;

  const RoomBlockTile({
    super.key,
    required this.block,
    required this.isConflict,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final color = teacherColor(block.teacherUserId);
    final borderColor = isConflict
        ? NebulaColors.errorRose
        : color.withValues(alpha: NebulaAlpha.border);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: NebulaAlpha.surface),
          borderRadius: BorderRadius.circular(NebulaRadii.card),
          border: Border.all(color: borderColor),
          boxShadow: isConflict
              ? [
                  BoxShadow(
                    color: NebulaColors.errorRose
                        .withValues(alpha: NebulaAlpha.accent),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: ClipRect(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                block.teacherName ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelM.copyWith(color: tokens.primaryText),
              ),
              Text(
                '${block.startTime}–${block.endTime}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodyS.copyWith(color: tokens.secondaryText).copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
