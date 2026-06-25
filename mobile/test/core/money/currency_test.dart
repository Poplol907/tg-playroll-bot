import 'package:cosmo_studio/core/money/currency.dart';
import 'package:flutter_test/flutter_test.dart';

// NumberFormat groups with a no-break space (U+00A0) or narrow no-break space
// (U+202F) depending on CLDR. Normalize both to a plain space so assertions
// don't depend on which one intl emits.
String norm(String s) => s.replaceAll(RegExp('[  ]'), ' ');

void main() {
  test('default active currency is Uzbek som', () {
    expect(Money.active.code, 'UZS');
    expect(Money.active.symbol, 'сум');
  });

  test('format adds the symbol after a space-grouped amount', () {
    expect(norm(Money.format(48000)), '48 000 сум');
    expect(norm(Money.format(1234567)), '1 234 567 сум');
    expect(Money.format(0), '0 сум');
  });

  test('amount groups without a symbol', () {
    expect(norm(Money.amount(48000)), '48 000');
    expect(Money.amount(0), '0');
  });

  test('format honours an explicit currency and symbol position', () {
    const usd = Currency(code: 'USD', symbol: r'$', symbolAfter: false);
    expect(norm(Money.format(1000, currency: usd)), r'$ 1 000');
  });
}
