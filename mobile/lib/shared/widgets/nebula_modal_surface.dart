import 'package:flutter/material.dart';

import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_surface_profile.dart';

enum NebulaModalChrome {
  sheet,
  dialog,
}

/// Canonical modal/sheet chrome.
///
/// Any modal-like surface should use this wrapper instead of resolving
/// [NebulaSurfaceProfile.modal] inside feature code. That keeps opacity,
/// matte fill, borders, radius, and shadow controlled from one place.
class NebulaModalSurface extends StatelessWidget {
  final Widget child;
  final Key? containerKey;
  final NebulaModalChrome chrome;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final BoxConstraints? constraints;

  const NebulaModalSurface({
    super.key,
    required this.child,
    this.containerKey,
    this.chrome = NebulaModalChrome.sheet,
    this.borderRadius,
    this.padding,
    this.width,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final surface = NebulaSurfaceProfile.modal.resolve(context);
    final radius = borderRadius ?? _defaultRadius;
    final border = chrome == NebulaModalChrome.dialog
        ? Border.all(
            color: surface.border,
            width: surface.borderWidth,
          )
        : Border(
            top: BorderSide(
              color: surface.border,
              width: surface.borderWidth,
            ),
            left: BorderSide(
              color: surface.border,
              width: surface.borderWidth,
            ),
            right: BorderSide(
              color: surface.border,
              width: surface.borderWidth,
            ),
          );

    return Container(
      key: containerKey,
      width: width,
      constraints: constraints,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: surface.occludingFill,
        borderRadius: radius,
        border: border,
        boxShadow: surface.shadows,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: surface.occludingFill,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: surface.sheen,
              borderRadius: radius,
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  BorderRadius get _defaultRadius => chrome == NebulaModalChrome.dialog
      ? NebulaRadii.modalBorder
      : NebulaRadii.sheetTopBorder;
}
