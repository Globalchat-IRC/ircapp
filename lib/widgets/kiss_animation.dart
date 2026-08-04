import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/vibrate_web.dart' if (dart.library.io) '../utils/vibrate_stub.dart'
    as vibrate;

class KissAnimation extends StatefulWidget {
  final String fromNick;
  final bool sentBySelf;
  final VoidCallback? onComplete;

  const KissAnimation({
    super.key,
    required this.fromNick,
    this.sentBySelf = false,
    this.onComplete,
  });

  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String fromNick) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (_) => KissAnimation(
        fromNick: fromNick,
        sentBySelf: false,
        onComplete: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  static void showSent(BuildContext context, String targetNick) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (_) => KissAnimation(
        fromNick: targetNick,
        sentBySelf: true,
        onComplete: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  @override
  State<KissAnimation> createState() => _KissAnimationState();
}

class _KissAnimationState extends State<KissAnimation>
    with TickerProviderStateMixin {
  late AnimationController _kissController;
  late AnimationController _fadeController;
  late AnimationController _heartsController;

  @override
  void initState() {
    super.initState();

    _triggerVibration();

    _kissController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _heartsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    _heartsController.forward();
    await _kissController.forward();

    await Future.delayed(const Duration(milliseconds: 800));

    await _fadeController.forward();

    widget.onComplete?.call();
  }

  void _triggerVibration() {
    if (kIsWeb) {
      vibrate.vibratePattern();
    } else {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _kissController.dispose();
    _fadeController.dispose();
    _heartsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _kissController,
        _fadeController,
        _heartsController,
      ]),
      builder: (context, _) {
        final bgAlpha = (_fadeController.value * -1.0 + 0.5).clamp(0.0, 1.0);
        return Material(
          color: Colors.black.withValues(alpha: bgAlpha),
          child: GestureDetector(
            onTap: () => widget.onComplete?.call(),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildFloatingHearts(),
                _buildKissEmoji(),
                _buildNickLabel(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKissEmoji() {
    final progress = Curves.easeOutBack.transform(_kissController.value);
    final fade = 1.0 - _fadeController.value;
    final bounce = 1.0 + math.sin(_kissController.value * math.pi) * 0.2;

    return Transform.scale(
      scale: progress * bounce,
      child: Opacity(
        opacity: fade,
        child: const Text(
          '\u{1F48B}',
          style: TextStyle(fontSize: 140),
        ),
      ),
    );
  }

  Widget _buildFloatingHearts() {
    final progress = _heartsController.value;
    final fade = (1.0 - _fadeController.value);
    if (progress <= 0) return const SizedBox.shrink();

    final hearts = <Widget>[];
    final rng = math.Random(42);
    for (int i = 0; i < 8; i++) {
      final delay = i * 0.08;
      final p = (progress - delay).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final x = (rng.nextDouble() - 0.5) * 300;
      final startY = 100.0;
      final endY = -200.0;
      final y = startY + (endY - startY) * Curves.easeOut.transform(p);
      final heartOpacity = (1.0 - p) * fade;
      final scale = 0.5 + rng.nextDouble() * 0.8;

      hearts.add(
        Positioned(
          left: MediaQuery.of(context).size.width / 2 + x,
          top: MediaQuery.of(context).size.height / 2 + y,
          child: Opacity(
            opacity: heartOpacity,
            child: Transform.scale(
              scale: scale,
              child: Text(
                rng.nextBool() ? '\u2764\uFE0F' : '\u{1F495}',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(child: Stack(children: hearts));
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
            color: Colors.pinkAccent.shade700,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Text(
            widget.sentBySelf
                ? 'Has enviado un beso a \${widget.fromNick}'
                : '\${widget.fromNick} te ha dado un beso',
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
