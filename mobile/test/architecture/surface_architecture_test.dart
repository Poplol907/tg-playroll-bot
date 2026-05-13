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
}
