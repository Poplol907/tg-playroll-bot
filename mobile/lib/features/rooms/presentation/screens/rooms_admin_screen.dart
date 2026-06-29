import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../widgets/room_edit_sheet.dart';

/// Rooms for the admin screen, optionally including archived ones.
final _adminRoomsProvider =
    FutureProvider.autoDispose.family<List<Room>, bool>((ref, includeInactive) {
  return ref
      .watch(roomsRepositoryProvider)
      .getRooms(includeInactive: includeInactive);
});

/// Admin screen to manage the studio's rooms: create, rename, archive/restore.
class RoomsAdminScreen extends ConsumerStatefulWidget {
  const RoomsAdminScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      SpacePageRoute(builder: (_) => const RoomsAdminScreen()),
    );
  }

  @override
  ConsumerState<RoomsAdminScreen> createState() => _RoomsAdminScreenState();
}

class _RoomsAdminScreenState extends ConsumerState<RoomsAdminScreen> {
  bool _showArchived = false;

  void _refresh() {
    ref.invalidate(_adminRoomsProvider);
    ref.invalidate(roomsProvider);
  }

  Future<void> _add() async {
    HapticFeedback.lightImpact();
    final ok = await RoomEditSheet.show(context);
    if (ok) _refresh();
  }

  Future<void> _rename(Room room) async {
    final ok = await RoomEditSheet.show(context, existing: room);
    if (ok) _refresh();
  }

  Future<void> _setActive(Room room, bool active) async {
    if (active == false) {
      final confirm = await NebulaDialog.confirm(
        context,
        title: 'Архивировать кабинет?',
        message:
            '«${room.name}» скроется с доски. Назначения сохранятся, кабинет можно вернуть.',
        confirmLabel: 'Архивировать',
      );
      if (!confirm) return;
    }
    try {
      await ref
          .read(roomsRepositoryProvider)
          .updateRoom(room.id, isActive: active);
      HapticFeedback.mediumImpact();
      _refresh();
    } catch (e) {
      if (mounted) {
        showNebulaSnackBar(
          context,
          title: 'Не удалось обновить',
          message: parseApiError(e, fallback: 'Попробуйте снова'),
          tone: NebulaSnackTone.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final canPop = Navigator.of(context).canPop();
    final roomsAsync = ref.watch(_adminRoomsProvider(_showArchived));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: AppScreenHeader(
                title: 'Кабинеты',
                subtitle: 'Управление',
                leading: canPop
                    ? IconButton(
                        tooltip: 'Назад',
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back_rounded,
                            color: tokens.mutedText),
                      )
                    : null,
                trailing: IconButton(
                  tooltip: 'Добавить кабинет',
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Показать архивные',
                      style: type.bodyM.copyWith(color: tokens.secondaryText),
                    ),
                  ),
                  Switch(
                    value: _showArchived,
                    onChanged: (v) => setState(() => _showArchived = v),
                    activeThumbColor: tokens.primaryAccent,
                  ),
                ],
              ),
            ),
            Expanded(
              child: roomsAsync.when(
                loading: () => const Center(child: OrbitLoader()),
                error: (e, _) => Center(
                  child: AppErrorCard(
                    message: parseApiError(e,
                        fallback: 'Не удалось загрузить кабинеты'),
                    onRetry: _refresh,
                    isConnectionError: isConnectionError(e),
                  ),
                ),
                data: (rooms) {
                  if (rooms.isEmpty) {
                    return Center(
                      child: Text(
                        _showArchived
                            ? 'Кабинетов пока нет'
                            : 'Активных кабинетов нет',
                        style: type.bodyM.copyWith(color: tokens.mutedText),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: rooms.length,
                    itemBuilder: (_, i) => _RoomRow(
                      room: rooms[i],
                      onTap: () => _rename(rooms[i]),
                      onArchive: rooms[i].isActive
                          ? () => _setActive(rooms[i], false)
                          : null,
                      onRestore: rooms[i].isActive
                          ? null
                          : () => _setActive(rooms[i], true),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomRow extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  const _RoomRow({
    required this.room,
    required this.onTap,
    this.onArchive,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: NebulaRadii.cardBorder,
          border: Border.all(color: tokens.surfaceBorder),
        ),
        child: Row(
          children: [
            Icon(
              Icons.meeting_room_outlined,
              size: 20,
              color: room.isActive ? tokens.primaryText : tokens.mutedText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.bodyL.copyWith(
                  color: room.isActive ? tokens.primaryText : tokens.mutedText,
                ),
              ),
            ),
            if (!room.isActive) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.mutedText.withValues(alpha: NebulaAlpha.subtle),
                  borderRadius: NebulaRadii.compactControlBorder,
                ),
                child: Text(
                  'в архиве',
                  style: type.labelS.copyWith(color: tokens.mutedText),
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (onArchive != null)
              IconButton(
                tooltip: 'Архивировать',
                onPressed: onArchive,
                icon: Icon(Icons.archive_outlined, color: tokens.mutedText),
              ),
            if (onRestore != null)
              IconButton(
                tooltip: 'Вернуть из архива',
                onPressed: onRestore,
                icon: Icon(Icons.unarchive_outlined,
                    color: tokens.primaryAccent),
              ),
          ],
        ),
      ),
    );
  }
}
