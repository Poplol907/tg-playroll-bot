import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../core/utils/error_parser.dart';
import '../../data/rates_repository.dart';
import '../../../../shared/widgets/sheet_error_banner.dart';

class SetRateSheet extends ConsumerStatefulWidget {
  final int teacherId;
  final int currentRate;
  const SetRateSheet(
      {super.key, required this.teacherId, required this.currentRate});

  static Future<bool> show(
      BuildContext context, int teacherId, int currentRate) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) =>
          SetRateSheet(teacherId: teacherId, currentRate: currentRate),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SetRateSheet> createState() => _SetRateSheetState();
}

class _SetRateSheetState extends ConsumerState<SetRateSheet> {
  late final _ctrl = TextEditingController(text: widget.currentRate.toString());
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rate = int.tryParse(_ctrl.text.trim());
    if (rate == null || rate <= 0) {
      setState(() => _error = 'Введите сумму больше нуля');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(ratesRepositoryProvider)
          .setDefaultRate(widget.teacherId, rate);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось изменить ставку');
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
          'Ставка за урок',
          style: type.titleL.copyWith(color: tokens.primaryText),
        ),
        const SizedBox(height: 20),
        NebulaInput(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          hintText: 'Сумма за урок',
          prefixIcon: const Icon(Icons.payments_outlined, size: 20),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),
        SheetErrorBanner(error: _error),
        StellarButton(
          label: 'Сохранить ставку',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.payments_rounded,
          color: tokens.primaryAccent,
        ),
      ],
    );
  }
}
