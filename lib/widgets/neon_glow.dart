import 'package:flutter/material.dart';

class NeonGlowText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final Color glowColor;
  final double glowRadius;
  final bool enabled;

  const NeonGlowText({
    super.key,
    required this.text,
    required this.style,
    this.glowColor = Colors.cyanAccent,
    this.glowRadius = 8.0,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return Text(text, style: style);
    }

    return Text(
      text,
      style: style.copyWith(
        shadows: [
          Shadow(color: glowColor.withValues(alpha: 0.8), blurRadius: glowRadius),
          Shadow(color: glowColor.withValues(alpha: 0.4), blurRadius: glowRadius * 2),
          Shadow(color: glowColor.withValues(alpha: 0.2), blurRadius: glowRadius * 3),
        ],
      ),
    );
  }
}

class NeonGlowContainer extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final Duration duration;

  const NeonGlowContainer({
    super.key,
    required this.child,
    this.glowColor = Colors.cyanAccent,
    this.glowRadius = 12.0,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<NeonGlowContainer> createState() => _NeonGlowContainerState();
}

class _NeonGlowContainerState extends State<NeonGlowContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final pulse = 0.5 + _controller.value * 0.5;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: 0.3 * pulse),
                blurRadius: widget.glowRadius * pulse,
                spreadRadius: 2 * pulse,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}
