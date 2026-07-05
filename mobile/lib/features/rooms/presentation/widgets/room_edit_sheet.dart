import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../core/utils/error_parser.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../data/room_models.dart';
import '../../data/rooms_repository.dart';
import '../../../../shared/widgets/sheet_error_banner.dart';

/// Create a new room or rename an existing one. Returns `true` from [show]
/// when the room was saved.
class RoomEditSheet extends ConsumerStatefulWidget {
  final Room? existing;

  const RoomEditSheet({super.key, this.existing});

  static Future<bool> show(BuildContext context, {Room? existing}) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => RoomEditSheet(existing: existing),
    );
    return result ?? false;
  }

  @override
  ConsumerState<RoomEditSheet> createState() => _RoomEditSheetState();
}

class _RoomEditSheetState extends ConsumerState<RoomEditSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.existing?.name ?? '');
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Введите название');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(roomsRepositoryProvider);
      if (_isEdit) {
        await repo.updateRoom(widget.existing!.id, name: name);
      } else {
        await repo.createRoom(name);
      }
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось сохранить');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEdit ? 'Переименовать кабинет' : 'Новый кабинет',
          style: type.titleL.copyWith(color: tokens.primaryText),
        ),
        const SizedBox(height: 20),
        NebulaInput(
          controller: _ctrl,
          hintText: 'Название кабинета',
          prefixIcon: const Icon(Icons.meeting_room_outlined, size: 20),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        SheetErrorBanner(error: _error),
        StellarButton(
          label: _isEdit ? 'Сохранить' : 'Создать',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.check_rounded,
          color: tokens.primaryAccent,
        ),
      ],
    );
  }
}
