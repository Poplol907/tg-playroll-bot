import 'package:flutter/material.dart';
import '../../../../core/theme/nebula_colors.dart';

/// Distinguishable, on-brand colors for teacher blocks on the room board.
const List<Color> teacherColorPalette = [
  NebulaColors.nebulaPurple,
  NebulaColors.stellarBlue,
  NebulaColors.auroraCyan,
  NebulaColors.plasmaPink,
  NebulaColors.successMint,
  NebulaColors.warningAmber,
  NebulaColors.cosmicRose,
];

/// Deterministic color for a teacher — same id maps to the same color across
/// days, so the board reads consistently.
Color teacherColor(int teacherUserId) =>
    teacherColorPalette[teacherUserId.abs() % teacherColorPalette.length];
