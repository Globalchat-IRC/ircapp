import 'package:flutter/material.dart';

/// Texto con sombra neon pulsante (glow) para nicks con rol.
class PulsingNeonText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color glowColor;
  final double minBlur;
  final double maxBlur;
  final double minAlpha;
  final double maxAlpha;
  final TextOverflow? overflow;
  final int? maxLines;

  const PulsingNeonText({
    super.key,
    required this.text,
    required this.style,
    required this.glowColor,
    this.minBlur = 3,
    this.maxBlur = 10,
    this.minAlpha = 0.3,
    this.maxAlpha = 0.9,
    this.overflow,
    this.maxLines,
  });

  @override
  State<PulsingNeonText> createState() => _PulsingNeonTextState();
}

class _PulsingNeonTextState extends State<PulsingNeonText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final t = _animation.value;
        final blur = widget.minBlur + (widget.maxBlur - widget.minBlur) * t;
        final alpha =
            widget.minAlpha + (widget.maxAlpha - widget.minAlpha) * t;
        return Text(
          widget.text,
          style: widget.style.copyWith(
            shadows: [
              Shadow(
                color: widget.glowColor.withValues(alpha: alpha),
                blurRadius: blur,
              ),
              Shadow(
                color: widget.glowColor.withValues(alpha: alpha * 0.4),
                blurRadius: blur * 2,
              ),
            ],
          ),
          overflow: widget.overflow,
          maxLines: widget.maxLines,
        );
      },
    );
  }
}
