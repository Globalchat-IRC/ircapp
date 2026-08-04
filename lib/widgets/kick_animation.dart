import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/vibrate_web.dart' if (dart.library.io) '../utils/vibrate_stub.dart'
    as vibrate;

class KickAnimation extends StatefulWidget {
  final String channel;
  final String reason;
  final String action; // 'kick', 'ban', 'expulsion'
  final VoidCallback? onComplete;

  const KickAnimation({
    super.key,
    required this.channel,
    this.reason = '',
    this.action = 'kick',
    this.onComplete,
  });

  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required String channel,
    String reason = '',
    String action = 'kick',
  }) {
    _currentEntry?.remove();
    _currentEntry = OverlayEntry(
      builder: (_) => KickAnimation(
        channel: channel,
        reason: reason,
        action: action,
        onComplete: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
      ),
    );
    Overlay.of(context).insert(_currentEntry!);
  }

  @override
  State<KickAnimation> createState() => _KickAnimationState();
}

class _KickAnimationState extends State<KickAnimation>
    with TickerProviderStateMixin {
  late AnimationController _bootController;
  late AnimationController _shakeController;
  late AnimationController _fadeController;
  late AnimationController _flashController;

  static const int _countdownStart = 10;
  int _countdown = _countdownStart;
  Timer? _countdownTimer;
  bool _finished = false;

  String get _emoji {
    switch (widget.action) {
      case 'ban':
        return '🚫';
      case 'expulsion':
        return '⛔';
      default:
        return '👢';
    }
  }

  String get _title {
    switch (widget.action) {
      case 'ban':
        return 'BANEADO';
      case 'expulsion':
        return 'EXPULSADO';
      default:
        return 'KICKEADO';
    }
  }

  Color get _actionColor {
    switch (widget.action) {
      case 'ban':
        return Colors.red;
      case 'expulsion':
        return Colors.orange.shade800;
      default:
        return Colors.amber.shade700;
    }
  }

  @override
  void initState() {
    super.initState();

    _triggerVibration();

    _bootController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await _bootController.forward();

    _shakeController.forward();
    _flashController.forward();

    _triggerVibration();

    await Future.delayed(const Duration(milliseconds: 300));
    _triggerVibration();

    // Contador de cuenta atrás: la pantalla se mantiene visible mientras cuenta.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
      });
      if (_countdown <= 0) {
        timer.cancel();
        _closeAnimation();
      }
    });
  }

  void _closeAnimation() {
    if (_finished) return;
    _finished = true;
    _fadeController.forward().then((_) {
      if (mounted) widget.onComplete?.call();
    });
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
    _countdownTimer?.cancel();
    _bootController.dispose();
    _shakeController.dispose();
    _fadeController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _bootController,
        _shakeController,
        _fadeController,
        _flashController,
      ]),
      builder: (context, _) {
        final bgAlpha = (_fadeController.value * -1.0 + 0.7).clamp(0.0, 1.0);
        final flashAlpha = _flashController.value > 0 && _flashController.value < 1
            ? (1.0 - _flashController.value) * 0.3
            : 0.0;
        return Material(
          color: Colors.black.withValues(alpha: bgAlpha),
          child: Stack(
            children: [
              // Red flash
              if (flashAlpha > 0)
                Container(
                  color: _actionColor.withValues(alpha: flashAlpha),
                ),
              GestureDetector(
                onTap: () => _closeAnimation(),
                child: _buildShakeWrapper(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildBoot(),
                      _buildCountdown(),
                      _buildInfo(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShakeWrapper({required Widget child}) {
    final shakeProgress = _shakeController.value;
    double shakeX = 0;
    double shakeY = 0;
    if (shakeProgress > 0 && shakeProgress < 1) {
      final decay = 1.0 - shakeProgress;
      shakeX = math.sin(shakeProgress * math.pi * 8) * 25 * decay;
      shakeY = math.cos(shakeProgress * math.pi * 6) * 10 * decay;
    }
    return Transform.translate(
      offset: Offset(shakeX, shakeY),
      child: child,
    );
  }

  Widget _buildBoot() {
    final bootProgress = Curves.elasticOut.transform(_bootController.value);

    final startY = -400.0;
    final endY = -40.0;
    final bootY = startY + (endY - startY) * bootProgress;

    final startRotation = -0.8;
    final endRotation = 0.0;
    final rotation =
        startRotation + (endRotation - startRotation) * bootProgress;

    final fade = 1.0 - _fadeController.value;

    return Transform.translate(
      offset: Offset(0, bootY),
      child: Transform.rotate(
        angle: rotation,
        child: Opacity(
          opacity: fade,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _emoji,
                style: const TextStyle(fontSize: 140),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: _actionColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _actionColor.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _actionColor.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  _title,
                  style: TextStyle(
                    color: _actionColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                    shadows: [
                      Shadow(
                        color: _actionColor.withValues(alpha: 0.6),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdown() {
    final fade = 1.0 - _fadeController.value;
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Opacity(
        opacity: fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Reconexión en',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.6),
                border: Border.all(color: _actionColor, width: 3),
              ),
              child: Center(
                child: Text(
                  '$_countdown',
                  style: TextStyle(
                    color: _actionColor,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Toca para cerrar antes',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfo() {
    final fade = 1.0 - _fadeController.value;
    final slideUp = Curves.easeOut.transform(_fadeController.value);

    return Positioned(
      bottom: 100 + slideUp * 40,
      left: 24,
      right: 24,
      child: Opacity(
        opacity: fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _actionColor.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Has sido expulsado de',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.channel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.reason.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _actionColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        widget.reason,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
