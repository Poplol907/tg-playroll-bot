import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_alpha.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../screens/room_schedule_screen.dart';
import 'room_edit_sheet.dart';

/// Horizontal strip of glass "digital room" tiles — tap a room to open its
/// weekly schedule. Admins can long-press to drag-reorder (persisted as
/// sort_order) and add via the ＋ tile. Tiles fade softly at the edges.
class RoomsStrip extends ConsumerStatefulWidget {
  const RoomsStrip({super.key});

  @override
  ConsumerState<RoomsStrip> createState() => _RoomsStripState();
}

class _RoomsStripState extends ConsumerState<RoomsStrip> {
  /// Local order — lets a drag settle instantly while the sort_order PATCH and
  /// refetch happen in the background.
  List<Room> _order = const [];

  /// Reconciles the server list with the local order: adopt the server order
  /// when membership changes (add/remove), else keep the local order and
  /// refresh each room's fields.
  List<Room> _sync(List<Room> server) {
    final prevIds = _order.map((r) => r.id).toSet();
    final serverIds = server.map((r) => r.id).toSet();
    if (prevIds.length != serverIds.length || !prevIds.containsAll(serverIds)) {
      return [...server];
    }
    final byId = {for (final r in server) r.id: r};
    return [for (final r in _order) byId[r.id]!];
  }

  Future<void> _add() async {
    HapticFeedback.lightImpact();
    final ok = await RoomEditSheet.show(context);
    if (ok) ref.invalidate(roomsProvider);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final moved = _order.removeAt(oldIndex);
      _order.insert(newIndex, moved);
    });
    HapticFeedback.mediumImpact();
    _persistOrder();
  }

  Future<void> _persistOrder() async {
    final ordered = _order;
    final repo = ref.read(roomsRepositoryProvider);
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].sortOrder != i) {
        try {
          await repo.updateRoom(ordered[i].id, sortOrder: i);
        } catch (_) {
          // Best-effort; a failed PATCH just leaves that room's order stale
          // until the next successful reorder.
        }
      }
    }
    ref.invalidate(roomsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final isAdmin = ref.watch(currentUserProvider)?.isAdmin ?? false;
    final roomsAsync = ref.watch(roomsProvider);

    return SizedBox(
      height: 112,
      child: roomsAsync.when(
        // Keep tiles visible during a refresh so an in-flight drag isn't
        // interrupted by a loader (order is tracked locally anyway).
        loading: () => const Center(child: OrbitLoader()),
        error: (_, __) => Center(
          child: Text('Не удалось загрузить кабинеты',
              style: type.bodyS.copyWith(color: tokens.mutedText)),
        ),
        data: (rooms) {
          _order = _sync(rooms);
          if (_order.isEmpty && !isAdmin) {
            return Center(
              child: Text('Кабинеты не созданы',
                  style: type.bodyS.copyWith(color: tokens.mutedText)),
            );
          }
          return _HorizontalEdgeFade(
            child: isAdmin
                ? ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    buildDefaultDragHandles: true,
                    // Transparent lift + iOS-style jiggle while the tile is
                    // being carried — тактильный сигнал «режим переноса».
                    proxyDecorator: (child, index, animation) => Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: _DragJiggle(child: child),
                    ),
                    onReorder: _onReorder,
                    footer: _AddTile(onTap: _add),
                    itemCount: _order.length,
                    itemBuilder: (context, i) {
                      final room = _order[i];
                      return Padding(
                        key: ValueKey(room.id),
                        padding: const EdgeInsets.only(right: 10),
                        child: _RoomTile(
                          room: room,
                          onTap: () =>
                              RoomScheduleScreen.show(context, room),
                        ),
                      );
                    },
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _order.length,
                    itemBuilder: (context, i) {
                      final room = _order[i];
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _RoomTile(
                          room: room,
                          onTap: () =>
                              RoomScheduleScreen.show(context, room),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

/// iOS-джиггл поднятой плитки: непрерывное лёгкое качание ±1.7° + небольшой
/// масштаб, пока палец несёт кабинет. Чисто флаттеровский AnimationController.
class _DragJiggle extends StatefulWidget {
  final Widget child;
  const _DragJiggle({required this.child});

  @override
  State<_DragJiggle> createState() => _DragJiggleState();
}

class _DragJiggleState extends State<_DragJiggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final angle = (_ctrl.value * 2 - 1) * 0.03; // ±1.7°
        return Transform.rotate(
          angle: angle,
          child: Transform.scale(scale: 1.05, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Soft left/right fade so tiles dissolve at the edges instead of being clipped.
class _HorizontalEdgeFade extends StatelessWidget {
  final Widget child;
  const _HorizontalEdgeFade({required this.child});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        final w = rect.width <= 0 ? 1.0 : rect.width;
        const fade = 22.0;
        final leftStop = (fade / w).clamp(0.0, 0.45);
        final rightStop = (1 - fade / w).clamp(0.55, 1.0);
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [
            Colors.transparent,
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0, leftStop, rightStop, 1],
        ).createShader(rect);
      },
      blendMode: BlendMode.dstIn,
      child: child,
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
    return NebulaSurface(
      width: 132,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
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
