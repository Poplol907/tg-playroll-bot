import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cosmo_studio/features/rooms/presentation/util/teacher_color.dart';

void main() {
  test('same teacher id always yields the same color', () {
    expect(teacherColor(42), teacherColor(42));
  });

  test('color is drawn from the published palette', () {
    expect(teacherColorPalette.contains(teacherColor(7)), isTrue);
  });

  test('handles negative / zero ids without throwing', () {
    expect(() => teacherColor(0), returnsNormally);
    expect(() => teacherColor(-3), returnsNormally);
  });
}
