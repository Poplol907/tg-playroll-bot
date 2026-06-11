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

  test('feature code does not resolve modal surface profiles directly', () {
    final modalProfileFiles =
        filesContaining('NebulaSurfaceProfile.modal.resolve');

    expect(
      modalProfileFiles,
      isEmpty,
      reason: 'Feature sheets must not build their own modal transparency. '
          'Use NebulaModalSurface, which intentionally shares the same card '
          'material as salary/calendar surfaces.',
    );
  });

  test('student detail content does not use whisper or mist surface fills', () {
    final content = File(
      'lib/features/students/presentation/widgets/student_detail_components.dart',
    ).readAsStringSync();

    expect(
      content,
      isNot(contains('NebulaAlpha.whisper')),
      reason: 'Student detail cards must read as dense matte surfaces, not '
          'near-transparent overlays.',
    );
    expect(
      content,
      isNot(contains('withValues(alpha: NebulaAlpha.mist)')),
      reason: 'Student detail cards must use NebulaSurface/card profiles '
          'instead of ultra-light raw fills.',
    );
  });

  test('student detail stats are one grouped surface, not separate islands',
      () {
    final content = File(
      'lib/features/students/presentation/widgets/student_detail_components.dart',
    ).readAsStringSync();

    expect(content, contains('class _StatsBlock'));
    expect(
      content,
      isNot(contains('class _StatTile')),
      reason: 'Stats inside the student profile are part of one profile card. '
          'Separate NebulaSurface islands are reserved for separated widgets.',
    );
  });

  test('legacy warm glass token usage stays allowlisted', () {
    final warmGlassFiles = {
      ...filesContaining('warmGlass'),
      ...filesContaining('warmPearlBorder'),
    }.toList()
      ..sort();

    expect(warmGlassFiles, [
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

    for (final file
        in dartFiles().where((f) => f.path.startsWith('lib/core/theme'))) {
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
    // 2026-05-16: 160 → 153 (MetricStat in admin)
    //             153 → 150 (IconCallout + ActionRow + StatusBadge migrations)
    //             150 → 146 (students NEW/EN badges, admin dialog rows)
    //             146 → 110 (student detail components + lesson_modal +
    //                        schedule_builder_modal cleanup pass)
    //             110 →  88 (calendar day-lessons sheet/dialog + add-lesson)
    //              88 →  42 (salary_components, server_settings_modal,
    //                        nebula_dialog, students_screen, view_as_banner,
    //                        admin+settings residuals)
    const baseline = 42;
    expect(
      count,
      lessThanOrEqualTo(baseline),
      reason: 'You added new hardcoded alpha values. Use NebulaAlpha.* from '
          'lib/core/theme/nebula_alpha.dart, then update the baseline.',
    );
  });

  // Core single-source-of-truth files must remain registered.
  // Removing one would silently break the architecture, so we assert they
  // exist and forbid widgets from reaching past them.
  test('core theme tokens are present as expected', () {
    expect(File('lib/core/theme/nebula_alpha.dart').existsSync(), isTrue);
    expect(File('lib/core/theme/nebula_typography.dart').existsSync(), isTrue);
    expect(File('lib/core/theme/nebula_layout.dart').existsSync(), isTrue);
    expect(File('lib/core/theme/nebula_semantic.dart').existsSync(), isTrue);
    expect(File('lib/core/theme/nebula_component_styles.dart').existsSync(),
        isTrue);
    expect(File('lib/core/theme/nebula_surface_profile.dart').existsSync(),
        isTrue);
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
    // 2026-05-16: 180 → 175 (MetricStat + Settings)
    //             175 → 169 (IconCallout + ActionRow + StatusBadge migrations)
    //             169 → 159 (students badges + admin titles & dialog rows)
    //             159 → 118 (student detail components + lesson_modal +
    //                        schedule_builder_modal cleanup pass)
    //             118 →  94 (calendar day-lessons sheet/dialog + add-lesson)
    //              94 →  46 (salary_components, server_settings_modal,
    //                        nebula_dialog, students_screen, view_as_banner,
    //                        admin+settings residuals)
    const baseline = 46;
    expect(
      count,
      lessThanOrEqualTo(baseline),
      reason: 'You added new hardcoded fontSize literals. Use '
          'NebulaTypography.of(context).<token>.copyWith(...) instead, '
          'then ratchet the baseline down.',
    );
  });
}
