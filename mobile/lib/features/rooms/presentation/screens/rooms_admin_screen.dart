import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/app_background_host.dart';
import '../../../../shared/widgets/app_error_card.dart';
import '../../../../shared/widgets/app_screen_header.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_segmented_control.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/nebula_text_button.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/space_page_transition.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../widgets/room_edit_sheet.dart';
import 'room_board_screen.dart';

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
    Navigator.of(context, rootNavigator: true).push(
      SlideUpPageRoute(builder: (_) => const RoomsAdminScreen()),
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
      body: AppBackgroundHost(
        darkBackground: AppDarkBackground.asciiWater,
        child: SafeArea(
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
                child: NebulaTextButton(
                  label: 'Расписание кабинетов',
                  icon: Icons.calendar_month_outlined,
                  onPressed: () => RoomBoardScreen.show(context),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: NebulaSegmentedControl(
                  segments: const ['Активные', 'Архив'],
                  selectedIndex: _showArchived ? 1 : 0,
                  onChanged: (i) => setState(() => _showArchived = i == 1),
                ),
              ),
              Expanded(
                child: roomsAsync.when(
                  skipLoadingOnRefresh: false,
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
                    // "Архив" shows only inactive rooms (getRooms(includeInactive)
                    // returns active + inactive, so filter down here).
                    final shown = _showArchived
                        ? rooms.where((r) => !r.isActive).toList()
                        : rooms;
                    if (shown.isEmpty) {
                      return Center(
                        child: Text(
                          _showArchived
                              ? 'Архив пуст'
                              : 'Активных кабинетов нет',
                          style: type.bodyM.copyWith(color: tokens.mutedText),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.25,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, i) => _RoomCard(
                        room: shown[i],
                        onTap: () => _rename(shown[i]),
                        onArchive: shown[i].isActive
                            ? () => _setActive(shown[i], false)
                            : null,
                        onRestore: shown[i].isActive
                            ? null
                            : () => _setActive(shown[i], true),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact room tile in the 2-column management grid.
class _RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onRestore;

  const _RoomCard({
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
    final archived = !room.isActive;
    final accent = archived ? tokens.mutedText : tokens.primaryAccent;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: NebulaRadii.cardBorder,
          border: Border.all(
            color: archived
                ? tokens.surfaceBorder
                : tokens.primaryAccent.withValues(alpha: NebulaAlpha.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: NebulaAlpha.surface),
                    borderRadius: NebulaRadii.controlBorder,
                  ),
                  child: Icon(Icons.meeting_room_rounded,
                      size: 18, color: accent),
                ),
                const Spacer(),
                if (onArchive != null)
                  _CornerAction(
                    icon: Icons.archive_outlined,
                    color: tokens.mutedText,
                    tooltip: 'Архивировать',
                    onTap: onArchive!,
                  ),
                if (onRestore != null)
                  _CornerAction(
                    icon: Icons.unarchive_outlined,
                    color: tokens.primaryAccent,
                    tooltip: 'Вернуть из архива',
                    onTap: onRestore!,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              room.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: type.titleS.copyWith(
                color: archived ? tokens.mutedText : tokens.primaryText,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: NebulaAlpha.subtle),
                borderRadius: NebulaRadii.compactControlBorder,
              ),
              child: Text(
                archived ? 'В архиве' : 'Активен',
                style: type.labelS.copyWith(color: accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small tap target for a card corner action (compact — the whole card is the
/// primary tap; these are secondary).
class _CornerAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _CornerAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
