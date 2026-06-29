import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_colors.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_dialog.dart';
import '../../../../shared/widgets/nebula_snackbar.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';

/// Admin sheet shown when tapping an existing block. For a recurring block:
/// cancel it on this date (adds an exception) or delete it entirely. For a
/// one-off: delete it. No edit — re-assigning is done by tapping an empty cell.
///
/// Returns `true` from [show] when something changed.
class BlockActionsSheet extends ConsumerStatefulWidget {
  final ResolvedRoomBlock block;
  final String dateYmd;

  const BlockActionsSheet({
    super.key,
    required this.block,
    required this.dateYmd,
  });

  static Future<bool> show(
    BuildContext context, {
    required ResolvedRoomBlock block,
    required String dateYmd,
  }) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => BlockActionsSheet(block: block, dateYmd: dateYmd),
    );
    return result ?? false;
  }

  @override
  ConsumerState<BlockActionsSheet> createState() => _BlockActionsSheetState();
}

class _BlockActionsSheetState extends ConsumerState<BlockActionsSheet> {
  bool _loading = false;

  Future<void> _cancelThisDay() async {
    setState(() => _loading = true);
    try {
      await ref
          .read(roomsRepositoryProvider)
          .cancelBlock(widget.block.id, widget.dateYmd);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showNebulaSnackBar(
          context,
          title: 'Не удалось отменить',
          message: parseApiError(e, fallback: 'Попробуйте снова'),
          tone: NebulaSnackTone.error,
        );
      }
    }
  }

  Future<void> _deleteEntirely() async {
    final confirmed = await NebulaDialog.confirm(
      context,
      title: 'Удалить блок?',
      message: widget.block.isRecurring
          ? 'Удалится повторяющийся блок на все дни.'
          : 'Удалится это назначение.',
      confirmLabel: 'Удалить',
      destructive: true,
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await ref.read(roomsRepositoryProvider).deleteBlock(widget.block.id);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showNebulaSnackBar(
          context,
          title: 'Не удалось удалить',
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
    final b = widget.block;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          b.teacherName ?? '—',
          style: type.titleL.copyWith(color: tokens.primaryText),
        ),
        const SizedBox(height: 4),
        Text(
          '${b.roomName} · ${b.startTime}–${b.endTime}',
          style: type.bodyM.copyWith(color: tokens.secondaryText),
        ),
        const SizedBox(height: 2),
        Text(
          b.isRecurring ? 'Повторяется еженедельно' : 'Разовое назначение',
          style: type.bodyS.copyWith(color: tokens.mutedText),
        ),
        if (b.note != null && b.note!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(b.note!, style: type.bodyS.copyWith(color: tokens.secondaryText)),
        ],
        const SizedBox(height: 24),
        if (b.isRecurring) ...[
          StellarButton(
            label: 'Отменить в этот день',
            loading: _loading,
            onPressed: _loading ? null : _cancelThisDay,
            icon: Icons.event_busy_rounded,
            color: tokens.warning,
          ),
          const SizedBox(height: 12),
          StellarButton(
            label: 'Удалить совсем',
            loading: _loading,
            onPressed: _loading ? null : _deleteEntirely,
            icon: Icons.delete_outline_rounded,
            color: NebulaColors.errorRose,
          ),
        ] else ...[
          StellarButton(
            label: 'Удалить',
            loading: _loading,
            onPressed: _loading ? null : _deleteEntirely,
            icon: Icons.delete_outline_rounded,
            color: NebulaColors.errorRose,
          ),
        ],
      ],
    );
  }
}
