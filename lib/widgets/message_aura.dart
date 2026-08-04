import 'dart:math' as math;
import 'package:flutter/material.dart';

class MessageAura extends StatefulWidget {
  final Widget child;
  final List<String> emojis;
  final bool enabled;
  final int particleCount;

  const MessageAura({
    super.key,
    required this.child,
    this.emojis = const ['✨', '💫', '⭐'],
    this.enabled = true,
    this.particleCount = 6,
  });

  @override
  State<MessageAura> createState() => _MessageAuraState();
}

class _MessageAuraState extends State<MessageAura>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<_ParticleData> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rng = math.Random();
    _particles = List.generate(widget.particleCount, (i) {
      return _ParticleData(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        speed: 0.2 + rng.nextDouble() * 0.6,
        size: 12 + rng.nextDouble() * 12,
        delay: rng.nextDouble(),
        emoji: widget.emojis[i % widget.emojis.length],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            ..._buildParticles(),
          ],
        );
      },
    );
  }

  List<Widget> _buildParticles() {
    final List<Widget> result = [];
    for (final p in _particles) {
      final t = (_controller.value * p.speed + p.delay) % 1.0;
      final opacity = (1.0 - (t * 2 - 0.5).abs().clamp(0.0, 1.0));
      if (opacity <= 0) continue;

      result.add(
        Positioned(
          left: p.x * 200 - 100,
          top: -20 + (1.0 - t) * -40,
          child: Opacity(
            opacity: opacity * 0.7,
            child: Text(
              p.emoji,
              style: TextStyle(fontSize: p.size * (0.5 + t * 0.5)),
            ),
          ),
        ),
      );
    }
    return result;
  }
}

class _ParticleData {
  final double x;
  final double y;
  final double speed;
  final double size;
  final double delay;
  final String emoji;

  _ParticleData({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.delay,
    required this.emoji,
  });
}
