import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_alpha.dart';
import '../../core/theme/nebula_radii.dart';
import '../../core/theme/nebula_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NebulaDrumPicker
//  Vertical scroll drum-roller with neon glow on the selected item.
//
//  Layout: shows 5 items at once, centre = selected (100% opacity + glow),
//  ±1 = 50 %, ±2 = 25 %.  Scroll or tap any item to select.
//
//  Inspired by the v0 ScrollTextAnimation component (React / Framer Motion).
// ─────────────────────────────────────────────────────────────────────────────

class NebulaDrumPicker extends StatefulWidget {
  final List<String> items;
  final int initialIndex;
  final ValueChanged<int> onChanged;
  final Color glowColor;
  final double itemExtent;
  final double fontSize;

  const NebulaDrumPicker({
    super.key,
    required this.items,
    required this.onChanged,
    this.initialIndex = 0,
    this.glowColor = NebulaColors.stellarBlue,
    this.itemExtent = 52.0,
    this.fontSize = 19.0,
  });

  @override
  State<NebulaDrumPicker> createState() => _NebulaDrumPickerState();
}

class _NebulaDrumPickerState extends State<NebulaDrumPicker> {
  late FixedExtentScrollController _ctrl;
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _ctrl = FixedExtentScrollController(initialItem: _selectedIndex);
  }

  @override
  void didUpdateWidget(NebulaDrumPicker old) {
    super.didUpdateWidget(old);
    if (old.glowColor != widget.glowColor) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _opacity(int index) {
    final distance = (index - _selectedIndex).abs();
    if (distance == 0) return 1.0;
    if (distance == 1) return 0.50;
    return 0.22;
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final totalHeight = widget.itemExtent * 5;
    final theme = Theme.of(context);
    final tokens =
        theme.extension<CosmoThemeTokens>() ?? CosmoThemeTokens.darkInternals;
    final isLight = theme.brightness == Brightness.light;
    // Светлая тема: softWhite-элементы и неоновое свечение тонули в белом.
    // Невыбранные — цвет текста темы; выбранный — акцент, притемнённый до
    // читаемого контраста; glow-тени только в тёмной.
    final selectedColor = isLight
        ? Color.lerp(widget.glowColor, tokens.primaryText, 0.45)!
        : widget.glowColor;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // ── Center highlight band ─────────────────────────────────────────
          Positioned(
            top: widget.itemExtent * 2,
            left: 16,
            right: 16,
            height: widget.itemExtent,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: NebulaRadii.controlBorder,
                  border: Border.symmetric(
                    horizontal: BorderSide(
                      color: widget.glowColor
                          .withValues(alpha: NebulaAlpha.accent),
                      width: 0.6,
                    ),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.transparent,
                      widget.glowColor.withValues(alpha: NebulaAlpha.mist),
                      widget.glowColor.withValues(alpha: NebulaAlpha.whisper),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Drum scroll ───────────────────────────────────────────────────
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.22, 0.78, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ListWheelScrollView.useDelegate(
              controller: _ctrl,
              itemExtent: widget.itemExtent,
              physics: const FixedExtentScrollPhysics(),
              perspective: 0.0025,
              diameterRatio: 5.0,
              onSelectedItemChanged: (index) {
                setState(() => _selectedIndex = index);
                HapticFeedback.selectionClick();
                widget.onChanged(index);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.items.length,
                builder: (context, index) {
                  final selected = index == _selectedIndex;
                  return GestureDetector(
                    onTap: () => _ctrl.animateToItem(
                      index,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
                    ),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize:
                              selected ? widget.fontSize + 1 : widget.fontSize,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w300,
                          color: selected
                              ? selectedColor
                              : tokens.primaryText
                                  .withValues(alpha: _opacity(index)),
                          shadows: selected && !isLight
                              ? [
                                  Shadow(
                                    color: widget.glowColor
                                        .withValues(alpha: NebulaAlpha.high),
                                    blurRadius: 16,
                                  ),
                                  Shadow(
                                    color: widget.glowColor
                                        .withValues(alpha: NebulaAlpha.medium),
                                    blurRadius: 32,
                                  ),
                                ]
                              : null,
                          letterSpacing: selected ? 0.5 : 0.0,
                        ),
                        child: Opacity(
                          opacity: _opacity(index),
                          child: Text(widget.items[index]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
