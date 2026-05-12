import 'package:cosmo_studio/core/theme/app_visual_mode.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('visual mode defaults to dark internals', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appVisualModeProvider), AppVisualMode.darkInternals);
  });

  test('visual mode can be changed for future theme selection', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(appVisualModeProvider.notifier).state =
        AppVisualMode.lightShader;

    expect(container.read(appVisualModeProvider), AppVisualMode.lightShader);
  });
}
