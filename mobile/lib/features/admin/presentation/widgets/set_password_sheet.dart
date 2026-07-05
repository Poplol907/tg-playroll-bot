import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../core/utils/error_parser.dart';
import '../../data/admin_repository.dart';
import '../../../../shared/widgets/sheet_error_banner.dart';

class SetPasswordSheet extends ConsumerStatefulWidget {
  final OrgUser user;
  const SetPasswordSheet({super.key, required this.user});

  static Future<bool> show(BuildContext context, OrgUser user) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => SetPasswordSheet(user: user),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SetPasswordSheet> createState() => _SetPasswordSheetState();
}

class _SetPasswordSheetState extends ConsumerState<SetPasswordSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pass = _ctrl.text;
    if (pass.length < 4) {
      setState(() => _error = 'Минимум 4 символа');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(adminRepositoryProvider).setPassword(widget.user.id, pass);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось изменить пароль');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Пароль для ${widget.user.displayName}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: tokens.primaryText,
          ),
        ),
        Text(
          '@${widget.user.login}',
          style: TextStyle(
            fontSize: 13,
            color: tokens.mutedText,
          ),
        ),
        const SizedBox(height: 20),
        NebulaInput(
          controller: _ctrl,
          obscureText: !_show,
          hintText: 'Новый пароль',
          prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
          suffixIcon: IconButton(
            icon: Icon(
              _show ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: tokens.mutedText,
              size: 18,
            ),
            onPressed: () => setState(() => _show = !_show),
          ),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),
        SheetErrorBanner(error: _error),
        StellarButton(
          label: 'Сохранить пароль',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.lock_rounded,
          color: tokens.primaryAccent,
        ),
      ],
    );
  }
}
