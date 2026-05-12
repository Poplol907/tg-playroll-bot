import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/cosmo_theme_tokens.dart';
import '../../core/theme/nebula_colors.dart';
import '../../core/theme/nebula_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NebulaInput — Glowing text field with cursor-following radial spotlight.
//  Adapted from the v0 Glowing Input component (React → Flutter).
//
//  Drop-in replacement for TextField / TextFormField.
//  Supports both field types via [isFormField] flag.
//
//  Performance notes:
//  • Glow drawn via CustomPainter (2 draw calls max).
//  • Cursor position tracked via ValueNotifier — no setState in parent.
//  • RepaintBoundary isolates the glow layer from the TextField subtree.
//  • BackdropFilter kept shallow (sigma ≤ 6) to stay within 120fps budget.
// ─────────────────────────────────────────────────────────────────────────────

class NebulaInput extends StatefulWidget {
  // ── Core TextField params ──────────────────────────────────────────────────
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;

  // ── Validation (TextFormField only) ────────────────────────────────────────
  final String? Function(String?)? validator;
  final bool isFormField;

  // ── Callbacks ──────────────────────────────────────────────────────────────
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  // ── Visual overrides ───────────────────────────────────────────────────────
  final Color glowColor;
  final double borderRadius;

  const NebulaInput({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.isFormField = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.glowColor = NebulaColors.stellarBlue,
    this.borderRadius = NebulaTokens.radiusSM,
  });

  @override
  State<NebulaInput> createState() => _NebulaInputState();
}

class _NebulaInputState extends State<NebulaInput>
    with SingleTickerProviderStateMixin {
  late final FocusNode _focus;
  late final AnimationController _glowCtrl;
  late final Animation<double> _glowAnim;

  // Cursor X offset in logical pixels (0 = left edge of text area)
  final _cursorX = ValueNotifier<double>(0.0);

  // Estimated horizontal padding (prefixIcon zone + left inset)
  static const double _textStartX = 48.0;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _glowAnim = CurvedAnimation(parent: _glowCtrl, curve: Curves.easeOut);

    _focus.addListener(_onFocusChange);
    widget.controller?.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(NebulaInput old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?.removeListener(_onTextChange);
      widget.controller?.addListener(_onTextChange);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    widget.controller?.removeListener(_onTextChange);
    _focus.dispose();
    _glowCtrl.dispose();
    _cursorX.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focus.hasFocus) {
      _glowCtrl.forward();
    } else {
      _glowCtrl.reverse();
    }
  }

  void _onTextChange() {
    final ctrl = widget.controller;
    if (ctrl == null) return;
    final text = ctrl.text;
    final selStart =
        ctrl.selection.isValid ? ctrl.selection.start : text.length;
    final textBefore = text.substring(0, selStart.clamp(0, text.length));
    _updateCursorX(textBefore);
  }

  void _onChangedInternal(String value) {
    // Measure cursor position from text before cursor
    final ctrl = widget.controller;
    final selStart =
        ctrl?.selection.isValid == true ? ctrl!.selection.start : value.length;
    final textBefore = value.substring(0, selStart.clamp(0, value.length));
    _updateCursorX(textBefore);
    widget.onChanged?.call(value);
  }

  void _updateCursorX(String textBefore) {
    const style = TextStyle(
      fontSize: 15,
      fontFamily: 'SpaceGrotesk',
    );
    final painter = TextPainter(
      text: TextSpan(text: textBefore, style: style),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    _cursorX.value = (_textStartX + painter.width).clamp(0, double.infinity);
  }

  InputDecoration _buildDecoration(bool isLight) {
    final labelColor = isLight ? const Color(0xFF6B7280) : NebulaColors.dimText;
    final hintColor  = isLight ? const Color(0xFF9CA3AF) : NebulaColors.ghostText;
    return InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      labelStyle: TextStyle(color: labelColor, fontSize: 14),
      hintStyle: TextStyle(color: hintColor, fontSize: 14),
      prefixIconColor: labelColor,
      suffixIconColor: labelColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextField(bool isLight) {
    final style = TextStyle(
      color: isLight ? const Color(0xFF111827) : NebulaColors.softWhite,
      fontSize: 15,
    );

    if (widget.isFormField) {
      return TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autocorrect: widget.autocorrect,
        readOnly: widget.readOnly,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        minLines: widget.minLines,
        style: style,
        decoration: _buildDecoration(isLight),
        cursorColor: widget.glowColor,
        cursorWidth: 1.5,
        validator: widget.validator,
        onChanged: _onChangedInternal,
        onFieldSubmitted: widget.onSubmitted,
        onTap: widget.onTap,
      );
    }

    return TextField(
      controller: widget.controller,
      focusNode: _focus,
      obscureText: widget.obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autocorrect: widget.autocorrect,
      readOnly: widget.readOnly,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      style: style,
      decoration: _buildDecoration(isLight),
      cursorColor: widget.glowColor,
      cursorWidth: 1.5,
      onChanged: _onChangedInternal,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens =
        theme.extension<CosmoThemeTokens>() ?? CosmoThemeTokens.darkInternals;
    final isLight = theme.brightness == Brightness.light;

    final effectiveRadius = widget.borderRadius;
    final idleBorderColor = tokens.surfaceBorder;
    final glassBg = isLight ? tokens.denseSurface : NebulaColors.denseNebulaSurface;

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) {
        final t = _glowAnim.value;
        final borderColor = Color.lerp(
          idleBorderColor,
          widget.glowColor.withValues(alpha: isLight ? 0.30 : 0.55),
          t,
        )!;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(effectiveRadius),
            border: Border.all(
              color: borderColor,
              width: isLight ? 1.0 : 0.8,
            ),
            boxShadow: t > 0.01
                ? [
                    BoxShadow(
                      color: widget.glowColor.withValues(
                        alpha:
                            (isLight ? 0.05 : 0.18) * tokens.glowIntensity * t,
                      ),
                      blurRadius: isLight ? 8 : 14,
                      spreadRadius: 0,
                      offset: Offset.zero,
                    ),
                  ]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
              child: Stack(
                children: [
                  // ── Glass base ──────────────────────────────────────────
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: glassBg,
                        borderRadius: BorderRadius.circular(effectiveRadius),
                      ),
                    ),
                  ),

                  // ── Cursor-following radial spotlight ───────────────────
                  if (t > 0.01)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: ValueListenableBuilder<double>(
                          valueListenable: _cursorX,
                          builder: (_, cursorX, __) => CustomPaint(
                            painter: _SpotlightPainter(
                              cursorX: cursorX,
                              color: widget.glowColor,
                              opacity:
                                  t * (isLight ? 0.35 : tokens.glowIntensity),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── TextField (on top) ──────────────────────────────────
                  child!,
                ],
              ),
            ),
          ),
        );
      },
      child: _buildTextField(isLight),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  CustomPainter — cursor-following radial spotlight (2 draw calls)
// ─────────────────────────────────────────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final double cursorX;
  final Color color;
  final double opacity;

  const _SpotlightPainter({
    required this.cursorX,
    required this.color,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = cursorX.clamp(24.0, size.width - 24.0);
    final cy = size.height / 2;
    final radius = size.width * 0.55;

    // Outer wide haze
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy), width: radius * 2, height: size.height * 1.4),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.13 * opacity),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius))
        ..blendMode = BlendMode.plus,
    );

    // Inner hot spot
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy), width: radius * 0.6, height: size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.10 * opacity),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: radius * 0.3))
        ..blendMode = BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.cursorX != cursorX || old.opacity != opacity || old.color != color;
}
