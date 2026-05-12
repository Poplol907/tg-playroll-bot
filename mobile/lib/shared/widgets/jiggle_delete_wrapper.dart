import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';

/// Long-press-to-delete wrapper with iOS-style jiggle animation.
///
/// Usage:
///   JiggleDeleteWrapper(
///     onTap: () { /* normal tap */ },
///     onDeleteConfirmed: () async { /* call API */ },
///     child: YourCard(),
///   )
///
/// Behaviour:
///   • Long press  → heavyImpact + card starts shaking ± 0.04 rad
///   • Red "Удалить" strip slides in below the card
///   • Tap delete  → [onDeleteConfirmed] called (shows spinner while running)
///   • Tap card    → cancels jiggle mode (no delete)
class JiggleDeleteWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Future<void> Function() onDeleteConfirmed;
  final String deleteLabel;

  /// Should match the card's own border radius so the strip blends in.
  final double borderRadius;

  const JiggleDeleteWrapper({
    super.key,
    required this.child,
    required this.onDeleteConfirmed,
    this.onTap,
    this.deleteLabel = 'Удалить',
    this.borderRadius = NebulaTokens.radiusMD,
  });

  @override
  State<JiggleDeleteWrapper> createState() => _JiggleDeleteWrapperState();
}

class _JiggleDeleteWrapperState extends State<JiggleDeleteWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shake;
  bool _jiggling = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 75),
    )..addStatusListener((s) {
        if (!_jiggling) return;
        if (s == AnimationStatus.completed) _shakeCtrl.reverse();
        if (s == AnimationStatus.dismissed) _shakeCtrl.forward();
      });
    _shake = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startJiggle() {
    if (_jiggling) return;
    HapticFeedback.heavyImpact();
    setState(() => _jiggling = true);
    _shakeCtrl.forward();
  }

  void _cancel() {
    if (!_jiggling) return;
    setState(() => _jiggling = false);
    _shakeCtrl
      ..stop()
      ..reset();
  }

  Future<void> _onDeleteTap() async {
    if (_deleting) return;
    _cancel();
    setState(() => _deleting = true);
    try {
      await widget.onDeleteConfirmed();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _startJiggle,
      onTap: _jiggling ? _cancel : widget.onTap,
      child: AnimatedBuilder(
        animation: _shake,
        builder: (_, child) => Transform.rotate(
          angle: _jiggling ? _shake.value : 0.0,
          child: child,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.child,
            // ── Delete strip ──────────────────────────────────────────────
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: _jiggling
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _onDeleteTap,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: NebulaColors.errorRose.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(widget.borderRadius),
                            bottomRight: Radius.circular(widget.borderRadius),
                          ),
                          border: Border(
                            top: BorderSide(
                              color:
                                  NebulaColors.errorRose.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                        child: _deleting
                            ? const Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: NebulaColors.errorRose,
                                  ),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_outline_rounded,
                                    color: NebulaColors.errorRose,
                                    size: 16,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Удалить',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: NebulaColors.errorRose,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
