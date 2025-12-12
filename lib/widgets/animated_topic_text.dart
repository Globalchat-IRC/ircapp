import 'package:flutter/material.dart';

class AnimatedTopicText extends StatefulWidget {
  final String topic;

  const AnimatedTopicText({Key? key, required this.topic}) : super(key: key);

  @override
  State<AnimatedTopicText> createState() => _AnimatedTopicTextState();
}

class _AnimatedTopicTextState extends State<AnimatedTopicText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double? _textWidth;
  double? _containerWidth;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateTextWidth();
  }

  @override
  void didUpdateWidget(AnimatedTopicText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.topic != widget.topic) {
      _controller.reset();
      _updateTextWidth();
      _controller.repeat();
    }
  }

  void _updateTextWidth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: widget.topic,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        setState(() {
          _textWidth = textPainter.width;
        });
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
    return LayoutBuilder(
      builder: (context, constraints) {
        _containerWidth = constraints.maxWidth;
        
        if (_textWidth == null) {
          return const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          );
        }

        final needsAnimation = _textWidth! > constraints.maxWidth;

        if (!needsAnimation) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                widget.topic,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Calcular la distancia total a desplazar
        final totalDistance = _textWidth! + 50; // 50px de espacio entre repeticiones
        
        _animation = Tween<double>(
          begin: 0,
          end: totalDistance,
        ).animate(CurvedAnimation(
          parent: _controller,
          curve: Curves.linear,
        ));

        return AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(-_animation.value, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      widget.topic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 50),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      widget.topic,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

