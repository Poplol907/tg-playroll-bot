import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final libDir = Directory('lib');
  final featureDir = Directory('lib/features');

  List<File> dartFiles(Directory directory) => directory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('application code does not use raw numeric corner radii', () {
    final rawCircular = RegExp(
      r'(?:BorderRadius|Radius)\.circular\(\s*[0-9]',
    );
    final rawProperty = RegExp(r'borderRadius:\s*[0-9]');
    final offenders = <String>[];

    for (final file in dartFiles(libDir)) {
      final content = file.readAsStringSync();
      if (rawCircular.hasMatch(content) || rawProperty.hasMatch(content)) {
        offenders.add(file.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use NebulaRadii or shape semantics. Derived painter geometry '
          'must be explicitly documented before it is allowlisted.',
    );
  });

  test('application code does not recreate the canonical pill as raw 999', () {
    final rawPill = RegExp(r'(?<![A-Za-z0-9_])999(?:\.0)?(?![A-Za-z0-9_])');
    final offenders = <String>[];

    for (final file in dartFiles(libDir)) {
      if (file.path.endsWith('core/theme/nebula_radii.dart')) continue;
      if (rawPill.hasMatch(file.readAsStringSync())) offenders.add(file.path);
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use NebulaRadiusRole.pill or NebulaRadii.pillBorder. The only '
          'numeric definition of the pill radius belongs in NebulaRadii.',
    );
  });

  test('removed size-based radius aliases do not return', () {
    final genericRadius = RegExp(r'NebulaTokens\.radius(?:XS|SM|MD|LG|XL)');
    final offenders = dartFiles(libDir)
        .where((file) => genericRadius.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'Choose a semantic role from NebulaRadii instead of a size.',
    );
  });

  test('feature surfaces cannot restore a free-form border radius', () {
    final override = RegExp(
      r'NebulaSurface\([\s\S]{0,240}?borderRadius:',
    );
    final offenders = dartFiles(featureDir)
        .where((file) => override.hasMatch(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

    expect(
      offenders,
      isEmpty,
      reason: 'NebulaSurface geometry comes from its profile or typed '
          'NebulaRadiusRole, never a free-form number.',
    );
  });

  test('intentional feature radius roles stay narrowly allowlisted', () {
    const allowedRoles = <String, Set<String>>{
      'lib/features/admin/presentation/screens/admin_screen.dart': {
        'card',
        'panel',
      },
      'lib/features/admin/presentation/widgets/view_as_banner.dart': {'pill'},
      'lib/features/auth/presentation/screens/login_screen.dart': {'panel'},
      'lib/features/calendar/presentation/screens/calendar_screen.dart': {
        'panel',
      },
      'lib/features/calendar/presentation/widgets/lesson_modal.dart': {
        'control',
      },
      'lib/features/salary/presentation/screens/salary_screen.dart': {
        'hero',
        'panel',
      },
      'lib/features/salary/presentation/widgets/salary_components.dart': {
        'control',
        'panel',
      },
      'lib/features/students/presentation/widgets/student_detail_components.dart':
          {
        'control',
      },
    };
    final rolePattern = RegExp(r'radiusRole:\s*NebulaRadiusRole\.(\w+)');
    final actual = <String, Set<String>>{};

    for (final file in dartFiles(featureDir)) {
      final roles = rolePattern
          .allMatches(file.readAsStringSync())
          .map((match) => match.group(1)!)
          .toSet();
      if (roles.isNotEmpty) actual[file.path] = roles;
    }

    expect(
      actual,
      allowedRoles,
      reason: 'Feature surfaces may select only reviewed semantic roles. '
          'New roles must describe real component geometry, not local tuning.',
    );
  });

  test('mathematical micro-geometry exceptions stay exact and documented', () {
    const exceptions = <String, Map<String, String>>{
      'lib/features/admin/presentation/widgets/view_as_banner.dart': {
        'Radius.circular(NebulaRadii.hero)':
            'derived clipping for the banner notch transition',
      },
      'lib/features/students/presentation/widgets/student_detail_components.dart':
          {
        'BorderRadius.circular(NebulaRadii.micro)':
            'tiny progress-track geometry, not a normal surface',
      },
    };
    final offenders = <String>[];

    for (final file in dartFiles(featureDir)) {
      final content = file.readAsStringSync();
      for (final match in RegExp(
        r'(?:BorderRadius|Radius)\.circular\(NebulaRadii\.(?:micro|hero)\)',
      ).allMatches(content)) {
        final pattern = match.group(0)!;
        if (!(exceptions[file.path]?.containsKey(pattern) ?? false)) {
          offenders.add('${file.path}: $pattern');
        }
      }
    }

    expect(offenders, isEmpty);
    for (final entry in exceptions.entries) {
      final content = File(entry.key).readAsStringSync();
      for (final exception in entry.value.entries) {
        expect(exception.value, isNotEmpty);
        expect(content, contains(exception.key));
      }
    }
  });

  test('canonical modal chrome resolves the modal profile', () {
    final content = File(
      'lib/shared/widgets/nebula_modal_surface.dart',
    ).readAsStringSync();

    expect(
      content,
      contains('NebulaSurfaceProfile.modal.resolve(context)'),
    );
  });
}
