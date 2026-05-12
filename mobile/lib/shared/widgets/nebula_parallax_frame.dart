import 'package:flutter/material.dart';

/// Lightweight pointer-based parallax depth.
///
/// Wraps [child] and applies a subtle Transform.translate driven by the
/// pointer's distance from the widget's centre.  Max displacement is
/// [maxOffset] pixels; [strength] controls how much of the distance is
/// converted to offset (default 0.025 = 2.5px per 100px from centre).
///
/// The translate smoothly follows/returns using TweenAnimationBuilder so
/// there is no explicit AnimationController to manage.
///
/// Automatically disabled when MediaQuery.disableAnimations is true.
class NebulaParallaxFrame extends StatefulWidget {
  final Widget child;
  final double strength;
  final double maxOffset;

  const NebulaParallaxFrame({
    super.key,
    required this.child,
    this.strength = 0.025,
    this.maxOffset = 5.0,
  });

  @override
  State<NebulaParallaxFrame> createState() => _NebulaParallaxFrameState();
}

class _NebulaParallaxFrameState extends State<NebulaParallaxFrame> {
  Offset _target = Offset.zero;

  void _onPointerMove(PointerMoveEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final centre = Offset(box.size.width / 2, box.size.height / 2);
    final local = box.globalToLocal(event.position);
    final raw = (local - centre) * widget.strength;
    final clamped = Offset(
      raw.dx.clamp(-widget.maxOffset, widget.maxOffset),
      raw.dy.clamp(-widget.maxOffset, widget.maxOffset),
    );
    if (clamped != _target) setState(() => _target = clamped);
  }

  void _resetTarget(PointerEvent _) {
    if (_target != Offset.zero) setState(() => _target = Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;

    return Listener(
      onPointerMove: _onPointerMove,
      onPointerUp: _resetTarget,
      onPointerCancel: _resetTarget,
      behavior: HitTestBehavior.translucent,
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(begin: Offset.zero, end: _target),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        builder: (_, offset, child) =>
            Transform.translate(offset: offset, child: child),
        child: widget.child,
      ),
    );
  }
}
