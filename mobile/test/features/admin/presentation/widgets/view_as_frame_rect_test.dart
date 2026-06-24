import 'package:cosmo_studio/features/admin/presentation/widgets/view_as_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('viewAsFrameRect insets by the safe area + margin so the frame '
      'traces the visible screen on any device', () {
    const size = Size(390, 844); // iPhone logical size
    const insets = EdgeInsets.only(top: 59, bottom: 34); // notch + home bar

    final rect = viewAsFrameRect(size, insets);

    expect(rect.left, 6); // 0 + margin
    expect(rect.top, 65); // 59 + margin
    expect(rect.right, 384); // 390 - 0 - margin
    expect(rect.bottom, 804); // 844 - 34 - margin
  });

  test('viewAsFrameRect collapses to empty when insets exceed the size', () {
    final rect = viewAsFrameRect(
      const Size(40, 40),
      const EdgeInsets.all(40),
    );
    expect(rect.width <= 0 || rect.height <= 0, isTrue);
  });
}
