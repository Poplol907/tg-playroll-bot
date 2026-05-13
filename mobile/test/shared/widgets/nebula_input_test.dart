import 'package:cosmo_studio/core/theme/app_theme.dart';
import 'package:cosmo_studio/shared/widgets/nebula_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('NebulaInput is blur-free by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightLite,
        home: const Scaffold(
          body: Center(
            child: NebulaInput(hintText: 'Server URL'),
          ),
        ),
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
  });
}
