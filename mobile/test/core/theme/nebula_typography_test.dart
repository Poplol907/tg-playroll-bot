import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/core/theme/nebula_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile typography scale uses ascending font sizes', () {
    const t = NebulaTypography.mobile;
    expect(t.displayL.fontSize, greaterThan(t.displayM.fontSize!));
    expect(t.displayM.fontSize, greaterThan(t.titleL.fontSize!));
    expect(t.titleL.fontSize, greaterThan(t.titleM.fontSize!));
    expect(t.titleM.fontSize, greaterThan(t.titleS.fontSize!));
    expect(t.titleS.fontSize, equals(t.bodyL.fontSize));
    expect(t.bodyL.fontSize, greaterThan(t.bodyM.fontSize!));
    expect(t.bodyM.fontSize, greaterThan(t.bodyS.fontSize!));
    expect(t.bodyS.fontSize, greaterThan(t.labelM.fontSize!));
    expect(t.labelM.fontSize, greaterThan(t.labelS.fontSize!));
    expect(t.labelS.fontSize, greaterThan(t.overline.fontSize!));
  });

  test('desktop typography enlarges only headings, keeps body identical', () {
    const m = NebulaTypography.mobile;
    final d = NebulaTypography.desktop;

    expect(d.displayL.fontSize, greaterThan(m.displayL.fontSize!));
    expect(d.displayM.fontSize, greaterThan(m.displayM.fontSize!));
    expect(d.titleL.fontSize, greaterThan(m.titleL.fontSize!));
    expect(d.titleM.fontSize, greaterThan(m.titleM.fontSize!));

    // Body / labels stay identical so reading rhythm is preserved.
    expect(d.bodyL.fontSize, equals(m.bodyL.fontSize));
    expect(d.bodyM.fontSize, equals(m.bodyM.fontSize));
    expect(d.bodyS.fontSize, equals(m.bodyS.fontSize));
    expect(d.labelM.fontSize, equals(m.labelM.fontSize));
    expect(d.labelS.fontSize, equals(m.labelS.fontSize));
    expect(d.overline.fontSize, equals(m.overline.fontSize));
  });

  test('mono token uses SpaceMono, others use SpaceGrotesk', () {
    const t = NebulaTypography.mobile;
    expect(t.mono.fontFamily, 'SpaceMono');
    expect(t.bodyM.fontFamily, 'SpaceGrotesk');
    expect(t.displayL.fontFamily, 'SpaceGrotesk');
  });

  testWidgets('app theme registers NebulaTypography as extension',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (ctx) {
            final type = NebulaTypography.of(ctx);
            return Text('hi', style: type.bodyM);
          },
        ),
      ),
    );
    expect(find.text('hi'), findsOneWidget);
    final BuildContext ctx = tester.element(find.text('hi'));
    expect(Theme.of(ctx).extension<NebulaTypography>(), isNotNull);
  });

  test('typography copyWith and lerp preserve identity', () {
    const a = NebulaTypography.mobile;
    final b = a.copyWith(bodyM: a.bodyM.copyWith(fontSize: 16));
    expect(b.bodyM.fontSize, 16);
    expect(b.displayL, a.displayL);
    final lerped = a.lerp(b, 0.0);
    expect(lerped.bodyM.fontSize, a.bodyM.fontSize);
  });
}
