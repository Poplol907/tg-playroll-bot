part of 'student_detail_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Physics toggle
// ─────────────────────────────────────────────────────────────────────────────

class _StatusToggle extends StatefulWidget {
  final bool isActive;
  final bool loading;
  final VoidCallback onToggle;

  const _StatusToggle(
      {required this.isActive, required this.loading, required this.onToggle});

  @override
  State<_StatusToggle> createState() => _StatusToggleState();
}

class _StatusToggleState extends State<_StatusToggle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  static const _spring =
      SpringDescription(mass: 1.0, stiffness: 800.0, damping: 28.0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this)
      ..value = widget.isActive ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_StatusToggle old) {
    super.didUpdateWidget(old);
    if (old.isActive != widget.isActive) {
      _ctrl.animateWith(SpringSimulation(
          _spring, _ctrl.value, widget.isActive ? 1.0 : 0.0, 0.0));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<CosmoThemeTokens>() ??
        CosmoThemeTokens.darkInternals;
    final type = NebulaTypography.of(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    // Выключенный трек должен читаться в ОБЕИХ темах: на светлой
    // surfaceBorder почти невидим и белая ручка тонула в белом.
    final offTrack = isLight
        ? tokens.mutedText.withValues(alpha: NebulaAlpha.accent)
        : tokens.surfaceBorder;
    final offBorder = isLight
        ? tokens.mutedText.withValues(alpha: NebulaAlpha.medium)
        : tokens.surfaceBorder;
    // Геометрия: контент лежит ВНУТРИ рамки 1.5 → внутренняя высота 27.
    // Ручка 24 центрируется отступом (27−24)/2 = 1.5 с обеих сторон —
    // раньше top:3 прижимал её к низу.
    const knob = 24.0;
    const inset = 1.5;
    const travel = 54.0 - 2 * 1.5 - 2 * inset - knob; // = 24

    return GestureDetector(
      onTap: widget.loading ? null : widget.onToggle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = _ctrl.value.clamp(0.0, 1.0);
              return Opacity(
                opacity: widget.loading ? 0.5 : 1.0,
                child: Container(
                  width: 54,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color.lerp(offTrack, tokens.success, t),
                    borderRadius: NebulaRadii.pillBorder,
                    border: Border.all(
                      color: Color.lerp(
                              offBorder,
                              tokens.success
                                  .withValues(alpha: NebulaAlpha.strong),
                              t) ??
                          Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: t > 0.05
                        ? [
                            BoxShadow(
                              color: tokens.success
                                  .withValues(alpha: NebulaAlpha.medium * t),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                  child: Stack(children: [
                    Positioned(
                      left: inset + _ctrl.value.clamp(0.0, 1.0) * travel,
                      top: inset,
                      bottom: inset,
                      child: Container(
                        width: knob,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withValues(alpha: NebulaAlpha.border),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            )
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Text(
              _ctrl.value > 0.5 ? 'Активен' : 'Неактивен',
              style: type.labelS.copyWith(
                color: _ctrl.value > 0.5 ? tokens.success : tokens.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
