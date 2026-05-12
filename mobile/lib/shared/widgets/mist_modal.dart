import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';
import 'adaptive_modal.dart';

/// Base bottom sheet surface using Nebula Material (dense variant).
/// Replaces solid containers in all bottom sheets with a warmGlass island.
///
/// Use [MistModal.show] as a drop-in for [showModalBottomSheet].
/// Wrap your sheet content in [MistModal] for standalone use inside builders.
class MistModal extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool showHandle;

  const MistModal({
    super.key,
    required this.child,
    this.padding,
    this.showHandle = true,
  });

  /// Shows a MistModal bottom sheet. Content builder receives standard context.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    double? maxHeightFraction,
    double desktopWidth = 480,
  }) {
    if (AppPlatform.isDesktop) {
      return AdaptiveModal.show<T>(
        context,
        builder: builder,
        isDismissible: isDismissible,
        desktopWidth: desktopWidth,
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      constraints: maxHeightFraction != null
          ? BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * maxHeightFraction,
            )
          : null,
      builder: (ctx) => MistModal(child: builder(ctx)),
    );
  }

  @override
  Widget build(BuildContext context) {
    const br = BorderRadius.vertical(
      top: Radius.circular(NebulaTokens.radiusLG),
    );
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: const BoxDecoration(
          gradient: NebulaColors.warmGlass,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NebulaTokens.radiusLG),
          ),
          border: Border(
            top: BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
            left: BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
            right: BorderSide(color: NebulaColors.warmPearlBorder, width: 0.8),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showHandle) ...[
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: NebulaColors.dimText.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(NebulaTokens.radiusXS),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Flexible(
              child: Padding(
                padding: padding ??
                    EdgeInsets.only(
                      left: NebulaTokens.sp20,
                      right: NebulaTokens.sp20,
                      bottom: MediaQuery.of(context).padding.bottom +
                          NebulaTokens.sp20,
                      top: showHandle ? 0 : NebulaTokens.sp20,
                    ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
