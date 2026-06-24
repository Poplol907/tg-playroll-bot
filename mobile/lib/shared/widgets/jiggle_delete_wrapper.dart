import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_radii.dart';

/// Long-press-to-delete wrapper with iOS-style jiggle animation.
///
/// Usage:
///   JiggleDeleteWrapper(
///     jiggleIndex: i,      // list index → staggered phase offset
///     onTap: () { ... },
///     onDeleteConfirmed: () async { ... },
///     child: YourCard(),
///   )
///
/// Behaviour:
///   • Long press  → heavyImpact + card starts shaking (organic, per-item phase)
///   • Red "Удалить" strip slides in below the card
///   • Tap delete  → exit animation (scale↓ opacity↓ blur↑), then onDeleteConfirmed
///   • Tap card    → cancels jiggle with smooth return to neutral
///   • prefers-reduced-motion: skips shake, shows strip immediately
class JiggleDeleteWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Future<void> Function() onDeleteConfirmed;
  final String deleteLabel;
  final double borderRadius;

  /// Pass the item's list index for per-item phase offset.
  /// Items with different indices will be out-of-phase with each other.
  final int jiggleIndex;

  const JiggleDeleteWrapper({
    super.key,
    required this.child,
    required this.onDeleteConfirmed,
    this.onTap,
    this.deleteLabel = 'Удалить',
    this.borderRadius = NebulaRadii.card,
    this.jiggleIndex = 0,
  });

  @override
  State<JiggleDeleteWrapper> createState() => _JiggleDeleteWrapperState();
}

class _JiggleDeleteWrapperState extends State<JiggleDeleteWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shakeCtrl;

  // Rotation: 0 → +0.032 → -0.028 → +0.016 → 0  (asymmetric weights = organic feel)
  late final Animation<double> _rotAnim;
  // Translate X: 0 → +1.6 → -1.2 → +0.5 → 0
  late final Animation<double> _txAnim;
  // Translate Y: 0 → -0.6 → +0.8 → -0.3 → 0
  late final Animation<double> _tyAnim;
  // Scale: 0.993 ↔ 1.007  (barely perceptible — adds micro-depth)
  late final Animation<double> _scaleAnim;

  bool _jiggling = false;
  bool _deleting = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Asymmetric TweenSequence: different weight ratios + different amplitude
    // on each segment make the motion feel hand-crafted, not generated.
    _rotAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.032)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.032, end: -0.028)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 38,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.028, end: 0.016)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.016, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
    ]).animate(_shakeCtrl);

    // TX uses different weights than rotation → different perceived phase
    _txAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.6)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.6, end: -1.2)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -1.2, end: 0.5)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 28,
      ),
      TweenSequenceItem(
        tween:
            Tween(begin: 0.5, end: 0.0).chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
    ]).animate(_shakeCtrl);

    _tyAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.6)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.6, end: 0.8)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 46,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.8, end: -0.3)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 22,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.3, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 10,
      ),
    ]).animate(_shakeCtrl);

    _scaleAnim = Tween<double>(begin: 0.993, end: 1.007).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.of(context).disableAnimations;
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
    if (_reduceMotion) return;
    // Phase offset: 6 evenly-spaced starting positions so adjacent list items
    // are never perfectly in sync — gives the iOS "chaos" feel.
    _shakeCtrl.value = (widget.jiggleIndex % 6) / 6.0;
    _shakeCtrl.repeat();
  }

  void _cancel() {
    if (!_jiggling) return;
    setState(() => _jiggling = false);
    if (_reduceMotion) {
      _shakeCtrl
        ..stop()
        ..reset();
      return;
    }
    // Animate back to value=0 where all transforms are at their neutral
    // position (rot=0, tx=0, ty=0) — feels like the card settles down.
    _shakeCtrl.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
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
      // ── Exit animation (scale + opacity + blur) ──────────────────────────
      // Driven by _deleting flag via AnimatedOpacity / AnimatedScale /
      // TweenAnimationBuilder — no separate controller needed.
      child: AnimatedOpacity(
        opacity: _deleting ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _deleting ? 0.78 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: _deleting ? 6.0 : 0.0),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            builder: (_, blur, child) => blur > 0.3
                ? ImageFiltered(
                    imageFilter:
                        ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                    child: child,
                  )
                : child!,
            // ── Jiggle transforms ─────────────────────────────────────────
            child: AnimatedBuilder(
              animation: _shakeCtrl,
              builder: (_, child) {
                final active = _jiggling && !_reduceMotion;
                return Transform.rotate(
                  angle: active ? _rotAnim.value : 0.0,
                  child: Transform.translate(
                    offset: active
                        ? Offset(_txAnim.value, _tyAnim.value)
                        : Offset.zero,
                    child: Transform.scale(
                      scale: active ? _scaleAnim.value : 1.0,
                      child: child,
                    ),
                  ),
                );
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.child,
                  // ── Delete strip ──────────────────────────────────────
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
                                color: NebulaColors.errorRose
                                    .withValues(alpha: 0.13),
                                borderRadius: BorderRadius.only(
                                  bottomLeft:
                                      Radius.circular(widget.borderRadius),
                                  bottomRight:
                                      Radius.circular(widget.borderRadius),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: NebulaColors.errorRose
                                        .withValues(alpha: 0.28),
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.delete_outline_rounded,
                                    color: NebulaColors.errorRose,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.deleteLabel,
                                    style: const TextStyle(
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
          ),
        ),
      ),
    );
  }
}
