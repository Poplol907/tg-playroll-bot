import 'package:flutter/material.dart';

import '../../core/theme/nebula_tokens.dart';

/// Shared desktop content rail for the app shell.
///
/// Keeps global chrome and route content in one readable column instead of
/// stretching mobile-oriented screens across very wide desktop windows.
class DesktopContentFrame extends StatelessWidget {
  final Widget header;
  final Widget child;
  final double maxWidth;

  const DesktopContentFrame({
    super.key,
    required this.header,
    required this.child,
    this.maxWidth = 1280,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 1200
            ? NebulaTokens.sp32
            : NebulaTokens.sp24;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
