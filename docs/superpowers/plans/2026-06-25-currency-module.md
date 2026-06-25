# Currency Module Implementation Plan (Plan A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Centralize all money formatting behind a single `Money`/`Currency` module and switch the app to Uzbek som ("сум"), so currency lives in one place (groundwork for future multi-currency).

**Architecture:** A `Currency` value object + a `Money` facade with `Money.active` (single source of truth), `Money.format(value)` (with symbol, e.g. "48 000 сум"), and `Money.amount(value)` (grouped number, no symbol). All existing ad-hoc formatters (`_formatMoney` in admin, `_fmt` + inline " сум" in salary) are replaced by it. Admin currently shows "₽"; salary already shows "сум" — this unifies both on `Money`.

**Tech Stack:** Flutter, intl (NumberFormat), flutter_test. All under `mobile/`.

**Branch:** Create `feature/currency-module` off `main` before Task 1. Do not work on `main`.

---

### Task 1: Money / Currency module

**Files:**
- Create: `mobile/lib/core/money/currency.dart`
- Test: `mobile/test/core/money/currency_test.dart`

- [ ] **Step 1: Write the failing test** — create `mobile/test/core/money/currency_test.dart`:

```dart
import 'package:cosmo_studio/core/money/currency.dart';
import 'package:flutter_test/flutter_test.dart';

// NumberFormat groups with a no-break space (U+00A0) or narrow no-break
// space (U+202F) depending on CLDR. Normalize both to a plain space.
String norm(String s) => s.replaceAll(RegExp(r'[  ]'), ' ');

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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/core/money/currency_test.dart`
Expected: FAIL — `currency.dart` does not exist.

- [ ] **Step 3: Implement the module** — create `mobile/lib/core/money/currency.dart`:

```dart
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/core/money/currency_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
git add mobile/lib/core/money/currency.dart mobile/test/core/money/currency_test.dart
git commit -m "feat(money): central Currency/Money module (default Uzbek som)

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 2: Migrate admin screen to Money

**Files:**
- Modify: `mobile/lib/features/admin/presentation/screens/admin_screen.dart`

Context: this file has THREE identical-ish `_formatMoney` methods (in three different widget classes) that hardcode "₽", called at lines 211, 443, 617. `NumberFormat` is used ONLY inside those three methods, so removing them makes the `intl` import unused.

- [ ] **Step 1: Add the Money import**

Add near the other `core/` imports at the top of `admin_screen.dart`:

```dart
import '../../../../core/money/currency.dart';
```

- [ ] **Step 2: Replace the three call sites**

- Line ~211: `value: _formatMoney(s.totalAmount),` → `value: Money.format(s.totalAmount),`
- Line ~443: inside the string, `${_formatMoney(totalAmount)}` → `${Money.format(totalAmount)}`
- Line ~617: `_formatMoney(s?.totalAmount ?? 0),` → `Money.format(s?.totalAmount ?? 0),`

- [ ] **Step 3: Delete the three `_formatMoney` methods**

Remove all three method definitions:

```dart
  String _formatMoney(int amount) {
    final formatter = NumberFormat.decimalPattern('ru');
    return '${formatter.format(amount)} ₽';
  }
```

and the variant:

```dart
  String _formatMoney(int amount) {
    if (amount == 0) return '0 ₽';
    final formatter = NumberFormat.decimalPattern('ru');
    return '${formatter.format(amount)} ₽';
  }
```

(There are three definitions total — two of the first form, one of the `if (amount == 0)` form. Remove all three. `Money.format(0)` returns "0 сум", preserving the zero case.)

- [ ] **Step 4: Remove the now-unused intl import**

Delete this line (it is no longer used anywhere in the file):

```dart
import 'package:intl/intl.dart';
```

- [ ] **Step 5: Verify**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze clean (no "unused import", no "undefined _formatMoney"); all tests pass.

- [ ] **Step 6: Commit**

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
git add mobile/lib/features/admin/presentation/screens/admin_screen.dart
git commit -m "refactor(admin): format money via Money module (₽ → сум)

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

### Task 3: Migrate salary to Money

**Files:**
- Modify: `mobile/lib/features/salary/presentation/screens/salary_screen.dart`
- Modify: `mobile/lib/features/salary/presentation/widgets/salary_components.dart` (a `part of` salary_screen — shares its imports)

Context: salary has a local `_fmt(int)` that groups a number with no symbol, used (a) bare for legend amounts (lines 406, 414) and the pending banner (line 479), and (b) with an inline " сум" suffix (lines 276, 314, 505, 511, 517, 524). `_PendingBanner.amount` is a `String`; `salary_components.dart:295` renders `'$amount сум — …'`. `intl` stays (DateFormat is still used at lines 46/47/183/184).

- [ ] **Step 1: Add the Money import**

Add near the other `core/` imports in `salary_screen.dart`:

```dart
import '../../../../core/money/currency.dart';
```

- [ ] **Step 2: Make `_fmt` delegate to Money.amount**

Replace:

```dart
  String _fmt(int amount) =>
      NumberFormat('#,###', 'ru').format(amount).replaceAll(',', ' ');
```

with:

```dart
  String _fmt(int amount) => Money.amount(amount);
```

(Legend amounts at lines 406/414 and any other bare `_fmt(...)` keep working — number only.)

- [ ] **Step 3: Replace the six symbol-bearing sites with Money.format**

- Line ~276: `'${_fmt((d.totalCurrent * ring).round())} сум',` → `Money.format((d.totalCurrent * ring).round()),`
- Line ~314: `'из ${_fmt(d.goalAmount)} сум',` → `'из ${Money.format(d.goalAmount)}',`
- Line ~505: `value: '${_fmt(d.advanceAmount)} сум',` → `value: Money.format(d.advanceAmount),`
- Line ~511: `value: '${_fmt(d.finalAmount)} сум',` → `value: Money.format(d.finalAmount),`
- Line ~517: `value: '${_fmt(d.totalAmount)} сум',` → `value: Money.format(d.totalAmount),`
- Line ~524: `'Куплено уроков: ${d.totalSubscribed}  •  Цель: ${_fmt(d.goalAmount)} сум',` → `'Куплено уроков: ${d.totalSubscribed}  •  Цель: ${Money.format(d.goalAmount)}',`

- [ ] **Step 4: Pass a fully-formatted amount into the pending banner**

- Line ~479: `entered(_PendingBanner(amount: _fmt(d.pendingAmount)), 0.35, 0.9),` → `entered(_PendingBanner(amount: Money.format(d.pendingAmount)), 0.35, 0.9),`

- [ ] **Step 5: Drop the inline " сум" in the banner component**

In `salary_components.dart`, replace:

```dart
              '$amount сум — пропуски ученика, будут зачислены в конце месяца',
```

with:

```dart
              '$amount — пропуски ученика, будут зачислены в конце месяца',
```

(`amount` is now `Money.format(...)`, i.e. already "48 000 сум".)

- [ ] **Step 6: Verify**

Run: `cd mobile && flutter analyze && flutter test`
Expected: analyze clean; all tests pass.

- [ ] **Step 7: Commit**

```bash
cd /Users/mickrusa4/Code/tg-playroll-bot
git add mobile/lib/features/salary/presentation/screens/salary_screen.dart \
        mobile/lib/features/salary/presentation/widgets/salary_components.dart
git commit -m "refactor(salary): format money via Money module

Co-Authored-By: claude-flow <ruv@ruv.net>"
```

---

## Self-review checklist (run after all tasks)

- `grep -rn "₽" mobile/lib` → no results (all "₽" gone).
- `grep -rn "_formatMoney" mobile/lib` → no results.
- `grep -rn "сум" mobile/lib` → only inside comments / none in display strings (the literal " сум" is now only inside `Currency.uzs`).
- `flutter analyze` clean, full suite green.

## Out of scope

- Plan B: teacher profile redesign (full screen) — uses `Money.format`, specced/approved separately.
- Multi-currency UI (switching currency at runtime, per-amount currencies) — the module is built to allow it, but no UI is added now.
