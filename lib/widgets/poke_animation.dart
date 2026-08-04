import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/vibrate_web.dart' if (dart.library.io) '../utils/vibrate_stub.dart'
    as vibrate;

class PokeAnimation extends StatefulWidget {
  final String fromNick;
  final VoidCallback? onComplete;

  const PokeAnimation({
    super.key,
    required this.fromNick,
    this.onComplete,
  });

  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String fromNick) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (_) => PokeAnimation(
        fromNick: fromNick,
        onComplete: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  @override
  State<PokeAnimation> createState() => _PokeAnimationState();
}

class _PokeAnimationState extends State<PokeAnimation>
    with TickerProviderStateMixin {
  late AnimationController _handController;
  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();

    _triggerVibration();

    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    // Hand slams in
    await _handController.forward();

    // Shake + ripple on impact
    _shakeController.forward();
    _rippleController.forward();

    // Vibrate again on impact
    _triggerVibration();

    // Hold for a moment
    await Future.delayed(const Duration(milliseconds: 800));

    // Fade out everything
    await _fadeController.forward();

    widget.onComplete?.call();
  }

  void _triggerVibration() {
    if (kIsWeb) {
      vibrate.vibratePattern();
    } else {
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _handController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _handController,
        _shakeController,
        _fadeController,
        _rippleController,
      ]),
      builder: (context, _) {
        final bgAlpha = (_fadeController.value * -1.0 + 0.6).clamp(0.0, 1.0);
        return Material(
          color: Colors.black.withValues(alpha: bgAlpha),
          child: GestureDetector(
            onTap: () => widget.onComplete?.call(),
            child: _buildShakeWrapper(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildRipple(),
                  _buildHand(),
                  _buildNickLabel(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShakeWrapper({required Widget child}) {
    final shakeProgress = _shakeController.value;
    double shakeX = 0;
    if (shakeProgress > 0 && shakeProgress < 1) {
      final decay = 1.0 - shakeProgress;
      shakeX = math.sin(shakeProgress * math.pi * 6) * 20 * decay;
    }
    return Transform.translate(
      offset: Offset(shakeX, 0),
      child: child,
    );
  }

  Widget _buildRipple() {
    final rippleProgress = Curves.easeOut.transform(_rippleController.value);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RipplePainter(progress: rippleProgress),
      ),
    );
  }

  Widget _buildHand() {
    final handProgress = Curves.easeOut.transform(_handController.value);

    final startY = -300.0;
    final endY = 0.0;
    final handY = startY + (endY - startY) * handProgress;

    final startRotation = -0.5;
    final endRotation = 0.0;
    final rotation =
        startRotation + (endRotation - startRotation) * handProgress;

    double scaleX = 1.0;
    double scaleY = 1.0;
    if (_shakeController.isAnimating || _shakeController.isCompleted) {
      final impactProgress = _shakeController.value;
      if (impactProgress < 0.15) {
        final t = impactProgress / 0.15;
        scaleX = 1.0 + 0.15 * t;
        scaleY = 1.0 - 0.1 * t;
      } else if (impactProgress < 0.3) {
        final t = (impactProgress - 0.15) / 0.15;
        scaleX = 1.15 - 0.15 * t;
        scaleY = 0.9 + 0.1 * t;
      }
    }

    final fade = 1.0 - _fadeController.value;

    return Transform.translate(
      offset: Offset(0, handY),
      child: Transform.rotate(
        angle: rotation,
        child: Transform.scale(
          scaleX: scaleX,
          scaleY: scaleY,
          child: Opacity(
            opacity: fade,
            child: const Text(
              '👊',
              style: TextStyle(fontSize: 120),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNickLabel() {
    final fade = 1.0 - _fadeController.value;
    final slideUp = Curves.easeOut.transform(_fadeController.value);

    return Positioned(
      bottom: 120 + slideUp * 40,
      child: Opacity(
        opacity: fade,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.teal.shade700,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Text(
            '${widget.fromNick} te ha dado un zumbido',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final double progress;

  _RipplePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.max(size.width, size.height) * 0.8;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (int i = 0; i < 3; i++) {
      final delay = i * 0.15;
      final p = (progress - delay).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final radius = maxRadius * Curves.easeOut.transform(p);
      final opacity = (1.0 - p) * 0.6;

      paint.color = Colors.teal.withValues(alpha: opacity);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
