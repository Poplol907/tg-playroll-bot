import 'package:intl/intl.dart';

/// A currency for displaying monetary amounts.
///
/// Groundwork for multi-currency: today the whole app uses [Currency.uzs],
/// but [Money.format] already accepts an explicit currency so individual
/// amounts can later be shown in different currencies.
class Currency {
  /// ISO-ish code, e.g. `UZS`.
  final String code;

  /// Display symbol, e.g. `сум`.
  final String symbol;

  /// `true` → "48 000 сум"; `false` → "$ 48 000".
  final bool symbolAfter;

  const Currency({
    required this.code,
    required this.symbol,
    this.symbolAfter = true,
  });

  /// Uzbek som — the app's default currency.
  static const uzs = Currency(code: 'UZS', symbol: 'сум');
}

/// Single source of truth for money formatting across the app. Swap the active
/// currency in one place instead of touching every screen.
class Money {
  Money._();

  /// App-wide active currency. Change this to switch the whole app.
  static Currency active = Currency.uzs;

  /// Grouped amount WITHOUT a currency symbol, e.g. `48000` → "48 000".
  /// Uses the `ru` grouping (no-break spaces) so long numbers never wrap
  /// mid-number.
  static String amount(int value) =>
      NumberFormat.decimalPattern('ru').format(value);

  /// Amount WITH the active (or given) currency symbol, e.g. "48 000 сум".
  static String format(int value, {Currency? currency}) {
    final c = currency ?? active;
    final grouped = amount(value);
    return c.symbolAfter ? '$grouped ${c.symbol}' : '${c.symbol} $grouped';
  }
}
