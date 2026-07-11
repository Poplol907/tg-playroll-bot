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

/// Конфигуратор ставки педагога: базовая + (опционально) иностранный тариф.
/// Без даты вступления — сервер держит одну текущую ставку на тариф.
class RateConfigSheet extends ConsumerStatefulWidget {
  final int teacherId;
  final CurrentRates current;
  const RateConfigSheet({
    super.key,
    required this.teacherId,
    required this.current,
  });

  static Future<bool> show(
      BuildContext context, int teacherId, CurrentRates current) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => RateConfigSheet(teacherId: teacherId, current: current),
    );
    return result ?? false;
  }

  @override
  ConsumerState<RateConfigSheet> createState() => _RateConfigSheetState();
}

class _RateConfigSheetState extends ConsumerState<RateConfigSheet> {
  late final _baseCtrl = TextEditingController(
      text: widget.current.base > 0 ? widget.current.base.toString() : '');
  late final _foreignCtrl =
      TextEditingController(text: widget.current.foreign?.toString() ?? '');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _baseCtrl.dispose();
    _foreignCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final base = int.tryParse(_baseCtrl.text.trim());
    if (base == null || base <= 0) {
      setState(() => _error = 'Введите ставку больше нуля');
      return;
    }
    final foreignText = _foreignCtrl.text.trim();
    int? foreign;
    if (foreignText.isNotEmpty) {
      foreign = int.tryParse(foreignText);
      if (foreign == null || foreign <= 0) {
        setState(() => _error = 'Иностранный тариф должен быть больше нуля');
        return;
      }
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(ratesRepositoryProvider).setCurrentRates(
            widget.teacherId,
            baseRate: base,
            foreignRate: foreign,
          );
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось сохранить ставку');
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
        Text('Ставка за урок',
            style: type.titleL.copyWith(color: tokens.primaryText)),
        const SizedBox(height: 20),
        NebulaInput(
          controller: _baseCtrl,
          keyboardType: TextInputType.number,
          hintText: 'Сумма за урок',
          prefixIcon: const Icon(Icons.payments_outlined, size: 20),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        NebulaInput(
          controller: _foreignCtrl,
          keyboardType: TextInputType.number,
          hintText: 'Иностранный тариф (необязательно)',
          prefixIcon: const Icon(Icons.translate_rounded, size: 20),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 8),
        Text(
          'Иностранный тариф применяется к ученикам с пометкой «иностранный». '
          'Пусто — будет базовая ставка.',
          style: type.labelS.copyWith(color: tokens.mutedText),
        ),
        const SizedBox(height: 20),
        SheetErrorBanner(error: _error),
        StellarButton(
          label: 'Сохранить',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.payments_rounded,
          color: tokens.primaryAccent,
        ),
      ],
    );
  }
}
