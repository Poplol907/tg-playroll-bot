import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../screens/room_schedule_screen.dart';
import 'room_edit_sheet.dart';

/// Horizontal strip of "digital rooms" — tap a room to open its weekly
/// schedule grid. Admins get a ＋ tile to add a room. Used on the admin home
/// and in the calendar's "Кабинеты" scope.
class RoomsStrip extends ConsumerWidget {
  const RoomsStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final roomsAsync = ref.watch(roomsProvider);

    Future<void> add() async {
      HapticFeedback.lightImpact();
      final ok = await RoomEditSheet.show(context);
      if (ok) ref.invalidate(roomsProvider);
    }

    return SizedBox(
      height: 112,
      child: roomsAsync.when(
        skipLoadingOnRefresh: false,
        loading: () => const Center(child: OrbitLoader()),
        error: (_, __) => Center(
          child: Text('Не удалось загрузить кабинеты',
              style: type.bodyS.copyWith(color: tokens.mutedText)),
        ),
        data: (rooms) {
          if (rooms.isEmpty && !isAdmin) {
            return Center(
              child: Text('Кабинеты не созданы',
                  style: type.bodyS.copyWith(color: tokens.mutedText)),
            );
          }
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final room in rooms)
                _RoomTile(
                  room: room,
                  onTap: () => RoomScheduleScreen.show(context, room),
                ),
              if (isAdmin) _AddTile(onTap: add),
            ],
          );
        },
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  const _RoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 132,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: NebulaRadii.cardBorder,
          border: Border.all(
            color: tokens.primaryAccent.withValues(alpha: NebulaAlpha.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tokens.primaryAccent.withValues(alpha: NebulaAlpha.surface),
                borderRadius: NebulaRadii.controlBorder,
              ),
              child: Icon(Icons.meeting_room_rounded,
                  size: 18, color: tokens.primaryAccent),
            ),
            const Spacer(),
            Text(
              room.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.titleS.copyWith(color: tokens.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 132,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surface.withValues(alpha: NebulaAlpha.mist),
          borderRadius: NebulaRadii.cardBorder,
          border: Border.all(color: tokens.surfaceBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.add_rounded, color: tokens.primaryAccent),
            const SizedBox(height: 8),
            Text('Добавить',
                style: type.bodyS.copyWith(color: tokens.mutedText)),
          ],
        ),
      ),
    );
  }
}
