import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final libDir = Directory('lib');

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  List<String> filesContaining(Pattern pattern) => dartFiles()
      .where((file) => file.readAsStringSync().contains(pattern))
      .map((file) => file.path)
      .toSet()
      .toList()
    ..sort();

  test('direct blur usage stays explicitly allowlisted', () {
    final directBlurFiles = {
      ...filesContaining('BackdropFilter('),
      ...filesContaining('ImageFilter.blur('),
      ...filesContaining('ui.ImageFilter.blur('),
    }.toList()
      ..sort();

    expect(directBlurFiles, [
      'lib/features/auth/presentation/screens/login_screen.dart',
      'lib/shared/widgets/jiggle_delete_wrapper.dart',
      'lib/shared/widgets/nebula_surface.dart',
    ]);
  });

  test('direct bottom sheet calls stay transition-debt allowlisted', () {
    final directSheetFiles = {
      ...filesContaining('showModalBottomSheet('),
      ...filesContaining('showModalBottomSheet<'),
    }.toList()
      ..sort();

    expect(directSheetFiles, [
      'lib/features/calendar/presentation/screens/calendar_screen.dart',
      'lib/features/calendar/presentation/widgets/day_lessons_sheet.dart',
      'lib/features/calendar/presentation/widgets/lesson_modal.dart',
      'lib/features/students/presentation/widgets/schedule_builder_modal.dart',
      'lib/features/students/presentation/widgets/student_detail_sheet.dart',
      'lib/shared/widgets/adaptive_modal.dart',
      'lib/shared/widgets/mist_modal.dart',
      'lib/shared/widgets/server_settings_modal.dart',
    ]);
  });

  test('legacy warm glass token usage stays allowlisted', () {
    final warmGlassFiles = {
      ...filesContaining('warmGlass'),
      ...filesContaining('warmPearlBorder'),
    }.toList()
      ..sort();

    expect(warmGlassFiles, [
      'lib/core/router/app_router.dart',
      'lib/core/theme/nebula_colors.dart',
    ]);
  });

  // ── Alpha token governance ──────────────────────────────────────────────────
  // Theme code is the single source of truth for opacity. Once we migrated the
  // values to NebulaAlpha, the theme layer must stay free of magic numbers so
  // global "сделать стекло плотнее" stays a one-line change.
  test('lib/core/theme uses NebulaAlpha — no magic alpha values', () {
    final pattern = RegExp(r'withValues\(alpha: [0-9]+\.[0-9]+\)');
    final offenders = <String>[];

    for (final file in dartFiles().where((f) => f.path.startsWith('lib/core/theme'))) {
      // The token file itself is allowed to have numeric literals (those ARE
      // the source of truth) and the doc-comments in nebula_alpha.dart.
      if (file.path == 'lib/core/theme/nebula_alpha.dart') continue;

      final content = file.readAsStringSync();
      final matches = pattern.allMatches(content);
      for (final m in matches) {
        offenders.add('${file.path} :: ${m.group(0)}');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Theme code must reference NebulaAlpha.* tokens. '
          'Replace numeric alpha with the closest semantic token. '
          'See lib/core/theme/nebula_alpha.dart.',
    );
  });

  // Feature + shared widget code still has many hardcoded alpha values.
  // We do not block all of them at once; we ratchet the baseline DOWN over
  // time. When migrating a screen, lower the limit and lock it in.
  test('feature/shared magic alpha usage stays within budget', () {
    final pattern = RegExp(r'withValues\(alpha: [0-9]+\.[0-9]+\)');
    int count = 0;
    for (final file in dartFiles()) {
      if (!file.path.startsWith('lib/features/') &&
          !file.path.startsWith('lib/shared/widgets/')) {
        continue;
      }
      count += pattern.allMatches(file.readAsStringSync()).length;
    }
    // BASELINE captured 2026-05-16 when NebulaAlpha was introduced.
    // RATCHET DOWN — never up. When you migrate a file, drop this number.
    const baseline = 160;
    expect(
      count,
      lessThanOrEqualTo(baseline),
      reason: 'You added new hardcoded alpha values. Use NebulaAlpha.* from '
          'lib/core/theme/nebula_alpha.dart, then update the baseline.',
    );
  });

  // Same ratchet for `fontSize: 12`-style magic numbers. Replace with a
  // `NebulaTypography.of(context).bodyM` (or copyWith) — never invent sizes.
  test('feature/shared magic fontSize usage stays within budget', () {
    final pattern = RegExp(r'fontSize: [0-9]+');
    int count = 0;
    for (final file in dartFiles()) {
      if (!file.path.startsWith('lib/features/') &&
          !file.path.startsWith('lib/shared/widgets/')) {
        continue;
      }
      count += pattern.allMatches(file.readAsStringSync()).length;
    }
    // BASELINE captured 2026-05-16 when NebulaTypography was introduced.
    // RATCHET DOWN as screens migrate to type.displayL / bodyM / etc.
    const baseline = 180;
    expect(
      count,
      lessThanOrEqualTo(baseline),
      reason: 'You added new hardcoded fontSize literals. Use '
          'NebulaTypography.of(context).<token>.copyWith(...) instead, '
          'then ratchet the baseline down.',
    );
  });
}
