import 'package:flutter/material.dart';
import '../../core/theme/nebula_colors.dart';

/// Semantic status dot with glow. Light is functional — communicates lesson state.
///
/// Statuses:
///   attended  → successMint,  steady glow
///   missed    → errorRose,    steady glow
///   cancelled → warningAmber, steady glow
///   scheduled → warningAmber, pulsing (unfilled past lesson)
///   today     → stellarBlue,  slow breathing pulse
class PulseIndicator extends StatefulWidget {
  final String status;
  final double size;

  const PulseIndicator({
    super.key,
    required this.status,
    this.size = 10,
  });

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  bool get _shouldPulse =>
      widget.status == 'scheduled' || widget.status == 'today';

  Duration get _pulseDuration => widget.status == 'today'
      ? const Duration(milliseconds: 2000)
      : const Duration(milliseconds: 700);

  Color get _color => switch (widget.status) {
        'attended'  => NebulaColors.successMint,
        'missed'    => NebulaColors.errorRose,
        'cancelled' => NebulaColors.warningAmber,
        'today'     => NebulaColors.stellarBlue,
        _           => NebulaColors.warningAmber, // scheduled / unfilled
      };

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _pulseDuration);
    _pulse = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (_shouldPulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PulseIndicator old) {
    super.didUpdateWidget(old);
    if (old.status != widget.status) {
      _ctrl.duration = _pulseDuration;
      if (_shouldPulse) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    final size = widget.size;

    if (!_shouldPulse) {
      return _GlowDot(color: color, size: size, glowAlpha: 0.45);
    }

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) =>
          _GlowDot(color: color, size: size, glowAlpha: _pulse.value),
    );
  }
}

class _GlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double glowAlpha;

  const _GlowDot({
    required this.color,
    required this.size,
    required this.glowAlpha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: glowAlpha),
            blurRadius: size * 1.6,
            spreadRadius: 0,
            offset: Offset.zero,
          ),
        ],
      ),
    );
  }
}
