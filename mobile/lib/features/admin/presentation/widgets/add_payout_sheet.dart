import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_input.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../../../core/utils/error_parser.dart';
import '../../data/payouts_repository.dart';
import '../../../../shared/widgets/sheet_error_banner.dart';

/// Добавление ИЛИ правка выплаты. Если [existing] задан — режим редактирования
/// (меняем сумму/дату) с кнопкой удаления.
class AddPayoutSheet extends ConsumerStatefulWidget {
  final int teacherId;
  final String monthYear;
  final int suggestedAmount;
  final PayoutModel? existing;
  const AddPayoutSheet({
    super.key,
    required this.teacherId,
    required this.monthYear,
    required this.suggestedAmount,
    this.existing,
  });

  static Future<bool> show(
    BuildContext context,
    int teacherId,
    String monthYear,
    int suggestedAmount, {
    PayoutModel? existing,
  }) async {
    final result = await MistModal.show<bool>(
      context: context,
      builder: (_) => AddPayoutSheet(
        teacherId: teacherId,
        monthYear: monthYear,
        suggestedAmount: suggestedAmount,
        existing: existing,
      ),
    );
    return result ?? false;
  }

  @override
  ConsumerState<AddPayoutSheet> createState() => _AddPayoutSheetState();
}

class _AddPayoutSheetState extends ConsumerState<AddPayoutSheet> {
  late final _ctrl = TextEditingController(
      text: (widget.existing?.amount ?? widget.suggestedAmount).toString());
  late DateTime _paidAt = widget.existing?.paidAt ?? DateTime.now();
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      locale: const Locale('ru'),
    );
    if (picked != null && mounted) setState(() => _paidAt = picked);
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_ctrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Введите сумму больше нуля');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(payoutsRepositoryProvider);
      if (_isEdit) {
        await repo.updatePayout(widget.existing!.id,
            amount: amount, paidAt: _paidAt);
      } else {
        await repo.addPayout(
          teacherId: widget.teacherId,
          monthYear: widget.monthYear,
          amount: amount,
          paidAt: _paidAt,
        );
      }
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось сохранить выплату');
      });
    }
  }

  Future<void> _delete() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref
          .read(payoutsRepositoryProvider)
          .deletePayout(widget.existing!.id);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      setState(() {
        _loading = false;
        _error = parseApiError(e, fallback: 'Не удалось удалить выплату');
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
        Text(_isEdit ? 'Изменить выплату' : 'Отметить выплату',
            style: type.titleL.copyWith(color: tokens.primaryText)),
        const SizedBox(height: 20),
        NebulaInput(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          hintText: 'Сумма выплаты',
          prefixIcon: const Icon(Icons.payments_outlined, size: 20),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _loading ? null : _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: NebulaRadii.controlBorder,
              border: Border.all(color: tokens.surfaceBorder),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 20, color: tokens.mutedText),
                const SizedBox(width: 12),
                Text(
                  DateFormat('d MMMM yyyy', 'ru').format(_paidAt),
                  style: type.bodyM.copyWith(color: tokens.primaryText),
                ),
                const Spacer(),
                Icon(Icons.edit_calendar_outlined,
                    size: 18, color: tokens.mutedText),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SheetErrorBanner(error: _error),
        StellarButton(
          label: 'Сохранить выплату',
          loading: _loading,
          onPressed: _loading ? null : _submit,
          icon: Icons.payments_rounded,
          color: tokens.primaryAccent,
        ),
        if (_isEdit) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: _loading ? null : _delete,
              icon: Icon(Icons.delete_outline_rounded,
                  size: 18, color: tokens.error),
              label: Text('Удалить выплату',
                  style: type.bodyM.copyWith(color: tokens.error)),
            ),
          ),
        ],
      ],
    );
  }
}
