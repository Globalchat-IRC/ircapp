import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/vibrate_web.dart' if (dart.library.io) '../utils/vibrate_stub.dart'
    as vibrate;

class ActionConfig {
  final String emoji;
  final String label;
  final Color color;
  final List<String> particles;
  final bool shake;

  const ActionConfig({
    required this.emoji,
    required this.label,
    required this.color,
    this.particles = const ['✨'],
    this.shake = false,
  });

  static const Map<String, ActionConfig> actions = {
    'kiss': ActionConfig(
      emoji: '💋',
      label: 'te ha dado un beso',
      color: Colors.pinkAccent,
      particles: ['❤️', '💕', '💖'],
    ),
    'poke': ActionConfig(
      emoji: '👊',
      label: 'te ha dado un zumbido',
      color: Colors.teal,
      particles: ['💥', '⚡'],
      shake: true,
    ),
    'slap': ActionConfig(
      emoji: '🤚',
      label: 'te ha dado una bofetada',
      color: Colors.red,
      particles: ['💥', '⭐', '💫'],
      shake: true,
    ),
    'hug': ActionConfig(
      emoji: '🤗',
      label: 'te ha dado un abrazo',
      color: Colors.orange,
      particles: ['❤️', '🧡', '💛'],
    ),
    'highfive': ActionConfig(
      emoji: '🙏',
      label: 'te ha dado un high five',
      color: Colors.amber,
      particles: ['✨', '⭐', '🌟'],
    ),
    'wave': ActionConfig(
      emoji: '👋',
      label: 'te ha saludado',
      color: Colors.blue,
      particles: ['✨', '💫'],
    ),
    'spray': ActionConfig(
      emoji: '💦',
      label: 'te ha rociado con agua',
      color: Colors.cyan,
      particles: ['💧', '💦', '🌊'],
    ),
    'coffee': ActionConfig(
      emoji: '☕',
      label: 'te ha dado un café',
      color: Colors.brown,
      particles: ['☕', '🫖'],
    ),
    'beer': ActionConfig(
      emoji: '🍺',
      label: 'te ha invitado una cerveza',
      color: Color(0xFFFF8F00),
      particles: ['🍺', '🍻', '🥂'],
    ),
    'fire': ActionConfig(
      emoji: '🔥',
      label: 'te ha lanzado fuego',
      color: Colors.deepOrange,
      particles: ['🔥', '💥', '🌋'],
    ),
    'money': ActionConfig(
      emoji: '💶',
      label: 'te ha susurrado billetes de 10€',
      color: Color(0xFF2E7D32),
      particles: ['💶', '💶', '🤑', '✨'],
    ),
  };
}

class ActionAnimation extends StatefulWidget {
  final String fromNick;
  final ActionConfig config;
  final VoidCallback? onComplete;

  const ActionAnimation({
    super.key,
    required this.fromNick,
    required this.config,
    this.onComplete,
  });

  static OverlayEntry? _currentEntry;

  static void show(BuildContext context, String fromNick, ActionConfig config) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (_) => ActionAnimation(
        fromNick: fromNick,
        config: config,
        onComplete: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  @override
  State<ActionAnimation> createState() => _ActionAnimationState();
}

class _ActionAnimationState extends State<ActionAnimation>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _fadeController;
  late AnimationController _particlesController;
  late AnimationController? _shakeController;

  @override
  void initState() {
    super.initState();

    _triggerVibration();

    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.config.shake) {
      _shakeController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    }

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    _particlesController.forward();
    await _mainController.forward();

    if (_shakeController != null) {
      _shakeController!.forward();
      _triggerVibration();
    }

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
    _mainController.dispose();
    _fadeController.dispose();
    _particlesController.dispose();
    _shakeController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animations = <Listenable>[
      _mainController,
      _fadeController,
      _particlesController,
    ];
    if (_shakeController != null) animations.add(_shakeController!);

    return AnimatedBuilder(
      animation: Listenable.merge(animations),
      builder: (context, _) {
        final bgAlpha = (_fadeController.value * -1.0 + 0.5).clamp(0.0, 1.0);
        return Material(
          color: Colors.black.withValues(alpha: bgAlpha),
          child: GestureDetector(
            onTap: () => widget.onComplete?.call(),
            child: _buildShakeWrapper(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildFloatingParticles(),
                  _buildMainEmoji(),
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
    if (_shakeController == null) return child;
    final shakeProgress = _shakeController!.value;
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

  Widget _buildMainEmoji() {
    final progress = Curves.easeOutBack.transform(_mainController.value);
    final fade = 1.0 - _fadeController.value;
    final bounce = 1.0 + math.sin(_mainController.value * math.pi) * 0.2;

    return Transform.scale(
      scale: progress * bounce,
      child: Opacity(
        opacity: fade,
        child: Text(
          widget.config.emoji,
          style: const TextStyle(fontSize: 140),
        ),
      ),
    );
  }

  Widget _buildFloatingParticles() {
    final progress = _particlesController.value;
    final fade = 1.0 - _fadeController.value;
    if (progress <= 0) return const SizedBox.shrink();

    final particles = <Widget>[];
    final rng = math.Random(42);
    final emojis = widget.config.particles;

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

      particles.add(
        Positioned(
          left: MediaQuery.of(context).size.width / 2 + x,
          top: MediaQuery.of(context).size.height / 2 + y,
          child: Opacity(
            opacity: heartOpacity,
            child: Transform.scale(
              scale: scale,
              child: Text(
                emojis[rng.nextInt(emojis.length)],
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(child: Stack(children: particles));
  }

  Widget _buildNickLabel() {
    final fade = 1.0 - _fadeController.value;
    final slideUp = Curves.easeOut.transform(_fadeController.value);
    final color = widget.config.color;

    return Positioned(
      bottom: 120 + slideUp * 40,
      child: Opacity(
        opacity: fade,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Text(
            '${widget.fromNick} ${widget.config.label}',
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
