import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_tokens.dart';
import '../../core/theme/nebula_typography.dart';
import 'nebula_surface.dart';
import 'nebula_text_button.dart';

enum NebulaSnackTone { success, warning, error, info }

OverlayEntry? _activeToast;

/// Shows a Nebula toast pinned to the TOP of the root overlay, just below the
/// status bar / Dynamic Island.
///
/// Top-anchored on the ROOT overlay on purpose: the toast lands at the exact
/// same height on every screen, above any bottom sheet, dialog or keyboard —
/// unlike ScaffoldMessenger snackbars whose position depends on the nearest
/// Scaffold's insets. Keeps the old call-site API.
void showNebulaSnackBar(
  BuildContext context, {
  required String title,
  String? message,
  NebulaSnackTone tone = NebulaSnackTone.info,
  Duration duration = const Duration(seconds: 3),
  // Опциональное действие («Отменить» и т.п.) — единственный undo-слот
  // приложения: тап по кнопке закрывает тост и вызывает [onAction].
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;

  // One toast at a time: a new message replaces the previous one instantly.
  _activeToast?.remove();
  _activeToast = null;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _NebulaToast(
      title: title,
      message: message,
      tone: tone,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
      onDismissed: () {
        if (_activeToast == entry) _activeToast = null;
        entry.remove();
      },
    ),
  );
  _activeToast = entry;
  overlay.insert(entry);
}

class _NebulaToast extends StatefulWidget {
  final String title;
  final String? message;
  final NebulaSnackTone tone;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  const _NebulaToast({
    required this.title,
    required this.message,
    required this.tone,
    required this.duration,
    required this.actionLabel,
    required this.onAction,
    required this.onDismissed,
  });

  @override
  State<_NebulaToast> createState() => _NebulaToastState();
}

class _NebulaToastState extends State<_NebulaToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;
  Timer? _autoClose;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: NebulaTokens.feedback,
      reverseDuration: NebulaTokens.tapFast,
    );
    _entry.forward();
    _autoClose = Timer(widget.duration, _close);
  }

  @override
  void dispose() {
    _autoClose?.cancel();
    _entry.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closing || !mounted) return;
    _closing = true;
    _autoClose?.cancel();
    await _entry.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final (accent, icon) = switch (widget.tone) {
      NebulaSnackTone.success => (
          NebulaColors.successMint,
          Icons.check_circle_rounded,
        ),
      NebulaSnackTone.warning => (
          NebulaColors.warningAmber,
          Icons.warning_amber_rounded,
        ),
      NebulaSnackTone.error => (
          NebulaColors.errorRose,
          Icons.error_outline_rounded,
        ),
      NebulaSnackTone.info => (
          NebulaColors.stellarBlue,
          Icons.info_outline_rounded,
        ),
    };

    // Fixed anchor: hardware top inset + one spacing step. Identical on every
    // route because the root overlay spans the whole app.
    final top = MediaQuery.viewPaddingOf(context).top + NebulaTokens.sp8;

    return Positioned(
      top: top,
      left: NebulaTokens.sp16,
      right: NebulaTokens.sp16,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _entry,
          builder: (context, child) {
            final t = Curves.easeOutCubic.transform(_entry.value);
            return Opacity(
              opacity: t,
              child: Transform.translate(
                // Enters from under the island; reduced motion = fade only.
                offset: reduceMotion ? Offset.zero : Offset(0, (t - 1) * 24),
                child: child,
              ),
            );
          },
          child: GestureDetector(
            onTap: _close,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -100) _close();
            },
            child: NebulaSurface(
              key: const ValueKey('nebula-toast'),
              dense: true,
              accent: accent,
              radiusRole: NebulaRadiusRole.card,
              padding: const EdgeInsets.symmetric(
                horizontal: NebulaTokens.sp16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 22),
                  const SizedBox(width: NebulaTokens.sp12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: type.bodyM.copyWith(
                            color: tokens.primaryText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.message != null &&
                            widget.message!.isNotEmpty) ...[
                          const SizedBox(height: NebulaTokens.sp2),
                          Text(
                            widget.message!,
                            style: type.labelM
                                .copyWith(color: tokens.secondaryText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (widget.actionLabel != null &&
                      widget.onAction != null) ...[
                    const SizedBox(width: NebulaTokens.sp8),
                    NebulaTextButton(
                      label: widget.actionLabel!,
                      color: accent,
                      compact: true,
                      onPressed: () {
                        _close();
                        widget.onAction!.call();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
