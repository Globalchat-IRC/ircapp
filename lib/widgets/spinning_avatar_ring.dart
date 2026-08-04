import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpinningAvatarRing extends StatefulWidget {
  final Widget child;
  final double size;
  final double ringWidth;
  final bool enabled;
  final Color? color;

  const SpinningAvatarRing({
    super.key,
    required this.child,
    required this.size,
    this.ringWidth = 3.0,
    this.enabled = true,
    this.color,
  });

  @override
  State<SpinningAvatarRing> createState() => _SpinningAvatarRingState();
}

class _SpinningAvatarRingState extends State<SpinningAvatarRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _SpinningRingPainter(
            progress: _controller.value,
            ringWidth: widget.ringWidth,
            color: widget.color,
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.ringWidth),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _SpinningRingPainter extends CustomPainter {
  final double progress;
  final double ringWidth;
  final Color? color;

  _SpinningRingPainter({required this.progress, required this.ringWidth, this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    List<Color> gradientColors;
    if (color != null) {
      final hsl = HSLColor.fromColor(color!);
      gradientColors = [
        hsl.withLightness((hsl.lightness + 0.2).clamp(0, 1)).toColor(),
        color!,
        hsl.withLightness((hsl.lightness - 0.2).clamp(0, 1)).toColor(),
        color!,
      ];
    } else {
      gradientColors = const [
        Color(0xFFFF00FF),
        Color(0xFF00FFFF),
        Color(0xFFFFFF00),
        Color(0xFFFF00FF),
      ];
    }

    final paint = Paint()
      ..shader = SweepGradient(
        startAngle: progress * 2 * math.pi,
        colors: gradientColors,
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_SpinningRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
