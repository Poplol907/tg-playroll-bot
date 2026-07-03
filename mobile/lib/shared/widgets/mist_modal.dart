import 'package:flutter/material.dart';
import '../../core/platform/app_platform.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_tokens.dart';
import '../providers/bottom_bar_visibility_provider.dart';
import 'adaptive_modal.dart';
import 'app_safe_layout.dart';
import 'frosted_sheet.dart';
import 'nebula_modal_surface.dart';

/// Canonical bottom sheet surface using the modal surface profile.
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
    return runWithBottomBarHidden<T>(context, () {
      return showFrostedSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled,
        isDismissible: isDismissible,
        enableDrag: enableDrag,
        useSafeArea: true,
        constraints: maxHeightFraction != null
            ? BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * maxHeightFraction,
              )
            : null,
        builder: (ctx) => MistModal(child: builder(ctx)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    return NebulaModalSurface(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHandle) ...[
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.mutedText.withValues(alpha: NebulaAlpha.medium),
                borderRadius: NebulaRadii.compactControlBorder,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: padding ??
                  AppSafeInsets.modal(
                    context,
                    top: showHandle ? 0 : NebulaTokens.sp20,
                  ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: media.viewInsets.bottom > 0 ? 0 : 1,
                ),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
