import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/money/currency.dart';
import '../../../../core/theme/cosmo_theme_tokens.dart';
import '../../../../core/theme/nebula_radii.dart';
import '../../../../core/theme/nebula_typography.dart';
import '../../../../shared/widgets/mist_modal.dart';
import '../../../../shared/widgets/nebula_surface.dart';
import '../../../../shared/widgets/orbit_loader.dart';
import '../../../../shared/widgets/stellar_button.dart';
import '../../data/payouts_repository.dart';
import 'add_payout_sheet.dart';

/// Список выплат педагога за месяц: тап по строке — правка/удаление,
/// кнопка снизу — добавить. Открывается со страницы «Выплаты» в профиле
/// педагога (админский аккаунт).
class PayoutsListSheet extends ConsumerWidget {
  final int teacherId;
  final String monthYear;
  final int owed;

  const PayoutsListSheet({
    super.key,
    required this.teacherId,
    required this.monthYear,
    required this.owed,
  });

  static Future<void> show(
      BuildContext context, int teacherId, String monthYear, int owed) {
    return MistModal.show<void>(
      context: context,
      builder: (_) => PayoutsListSheet(
        teacherId: teacherId,
        monthYear: monthYear,
        owed: owed,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final args = (teacherId: teacherId, monthYear: monthYear);
    final payoutsAsync = ref.watch(teacherPayoutsProvider(args));

    void refresh() => ref.invalidate(teacherPayoutsProvider(args));

    Future<void> addNew() async {
      final paid =
          payoutsAsync.valueOrNull?.fold<int>(0, (s, p) => s + p.amount) ?? 0;
      final suggested = (owed - paid).clamp(0, owed).toInt();
      final ok = await AddPayoutSheet.show(context, teacherId, monthYear, suggested);
      if (ok) refresh();
    }

    Future<void> edit(PayoutModel p) async {
      final ok = await AddPayoutSheet.show(
          context, teacherId, monthYear, p.amount,
          existing: p);
      if (ok) refresh();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Выплаты за месяц',
            style: type.titleL.copyWith(color: tokens.primaryText)),
        const SizedBox(height: 16),
        payoutsAsync.when(
          skipLoadingOnRefresh: false,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: OrbitLoader()),
          ),
          error: (_, __) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('Не удалось загрузить выплаты',
                style: type.bodyM.copyWith(color: tokens.mutedText)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Выплат за месяц ещё нет',
                    style: type.bodyM.copyWith(color: tokens.mutedText)),
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final p in list) ...[
                      _PayoutRow(payout: p, onTap: () => edit(p)),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        StellarButton(
          label: 'Добавить выплату',
          icon: Icons.add_rounded,
          onPressed: addNew,
          color: tokens.primaryAccent,
        ),
      ],
    );
  }
}

class _PayoutRow extends StatelessWidget {
  final PayoutModel payout;
  final VoidCallback onTap;

  const _PayoutRow({required this.payout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: NebulaSurface(
        dense: true,
        radiusRole: NebulaRadiusRole.control,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.payments_outlined, size: 18, color: tokens.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                DateFormat('d MMMM yyyy', 'ru').format(payout.paidAt),
                style: type.bodyM.copyWith(color: tokens.primaryText),
              ),
            ),
            Text(
              Money.format(payout.amount),
              style: type.bodyM.copyWith(
                color: tokens.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 18, color: tokens.mutedText),
          ],
        ),
      ),
    );
  }
}
