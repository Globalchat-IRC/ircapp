import 'dart:async';
import 'package:flutter/material.dart';

class GiftPopup extends StatefulWidget {
  final String senderNick;
  final String giftIcon;
  final String giftName;
  final VoidCallback? onDismiss;

  const GiftPopup({
    super.key,
    required this.senderNick,
    required this.giftIcon,
    required this.giftName,
    this.onDismiss,
  });

  static void show(BuildContext context, {
    required String senderNick,
    required String giftIcon,
    required String giftName,
  }) {
    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (_) => GiftPopup(
        senderNick: senderNick,
        giftIcon: giftIcon,
        giftName: giftName,
        onDismiss: () => entry?.remove(),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  @override
  State<GiftPopup> createState() => _GiftPopupState();
}

class _GiftPopupState extends State<GiftPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnim = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.3),
    ));
    _controller.forward();
    Timer(const Duration(seconds: 4), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss?.call());
      }
    });
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
      builder: (context, child) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () {
                _controller.reverse().then((_) => widget.onDismiss?.call());
              },
              child: Container(
                color: Colors.black.withValues(alpha: 0.4 * _fadeAnim.value),
              ),
            ),
            Center(
              child: Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _fadeAnim.value,
                  child: Stack(
                    children: [
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.giftIcon,
                            style: const TextStyle(fontSize: 80),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${widget.senderNick} te ha enviado un regalo!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.giftName,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () {
                            _controller.reverse().then((_) => widget.onDismiss?.call());
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
