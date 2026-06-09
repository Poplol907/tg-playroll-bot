import 'package:flutter/material.dart';
import '../../core/platform/app_platform.dart';
import 'nebula_modal_surface.dart';

/// Показывает bottom sheet на мобайле и Dialog на десктопе.
/// Используй вместо прямого вызова [showModalBottomSheet].
abstract class AdaptiveModal {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    double mobileInitialSize = 0.65,
    double desktopWidth = 480,
  }) {
    if (AppPlatform.isDesktop) {
      return _showDesktopDialog<T>(
        context,
        builder: builder,
        isDismissible: isDismissible,
        width: desktopWidth,
      );
    }
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      isDismissible: isDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) {
        final media = MediaQuery.of(ctx);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: media.size.height * 0.9,
            ),
            child: builder(ctx),
          ),
        );
      },
    );
  }

  static Future<T?> _showDesktopDialog<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
    required double width,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (ctx) => _DesktopDialogWrapper(
        width: width,
        child: builder(ctx),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Обёртка диалога для десктопа — canonical modal surface profile
// ─────────────────────────────────────────────────────────────────────────────

class _DesktopDialogWrapper extends StatelessWidget {
  final Widget child;
  final double width;

  const _DesktopDialogWrapper({
    required this.child,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: NebulaModalSurface(
        containerKey: const ValueKey('adaptive-modal-desktop-surface'),
        chrome: NebulaModalChrome.dialog,
        width: width,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: child,
      ),
    );
  }
}
