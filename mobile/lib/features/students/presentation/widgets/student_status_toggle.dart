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
                    color: Color.lerp(
                        tokens.surfaceBorder, tokens.success, t),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Color.lerp(
                              tokens.surfaceBorder,
                              tokens.success.withValues(alpha: 0.6),
                              t) ??
                          Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: t > 0.05
                        ? [
                            BoxShadow(
                              color: tokens.success.withValues(
                                  alpha: (t * 0.45).clamp(0.0, 0.45)),
                              blurRadius: 12,
                            )
                          ]
                        : null,
                  ),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Positioned(
                      left: 3 + _ctrl.value.clamp(0.0, 1.0) * 24,
                      top: 3,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
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
              style: TextStyle(
                fontSize: 10,
                color: _ctrl.value > 0.5
                    ? tokens.success
                    : tokens.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
