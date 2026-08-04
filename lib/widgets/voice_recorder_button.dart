import 'dart:async';
import 'dart:typed_data' show Uint8List;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:irc_app/utils/voice_recorder_web.dart'
    if (dart.library.html) 'package:irc_app/utils/voice_recorder_web.dart'
    if (dart.library.io) 'package:irc_app/utils/voice_recorder_web_stub.dart';

class VoiceRecorderButton extends ConsumerStatefulWidget {
  final String channel;
  final ValueChanged<Uint8List>? onAudioRecorded;
  final String Function()? mimeTypeOf;
  final VoidCallback? onSent;

  const VoiceRecorderButton({
    super.key,
    required this.channel,
    this.onAudioRecorded,
    this.mimeTypeOf,
    this.onSent,
  });

  @override
  ConsumerState<VoiceRecorderButton> createState() => _VoiceRecorderButtonState();
}

class _VoiceRecorderButtonState extends ConsumerState<VoiceRecorderButton>
    with SingleTickerProviderStateMixin {
  final VoiceRecorderWeb _recorder = VoiceRecorderWeb();
  bool _isRecording = false;
  bool _isSending = false;
  int _seconds = 0;
  Timer? _timer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (!kIsWeb) return;
    if (_isRecording) return;
    try {
      final started = await _recorder.start();
      if (!started) {
        debugPrint('❌ No se pudo iniciar la grabación de voz');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudo acceder al micrófono. Revisa los permisos del navegador.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      if (!mounted) {
        _recorder.cancel();
        return;
      }
      setState(() {
        _isRecording = true;
        _seconds = 0;
      });
      _pulseController.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (mounted) setState(() => _seconds++);
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();

    setState(() {
      _isRecording = false;
      _isSending = true;
    });

    final bytes = await _recorder.stop();

    if (!mounted) return;

    setState(() {
      _isSending = false;
      _seconds = 0;
    });

    if (bytes != null && bytes.isNotEmpty) {
      widget.onAudioRecorded?.call(bytes);
    }

    widget.onSent?.call();
  }

  void _cancelRecording() {
    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _recorder.cancel();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _isSending = false;
        _seconds = 0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    if (_isRecording) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 12 + _pulseController.value * 6,
                height: 12 + _pulseController.value * 6,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.3 + _pulseController.value * 0.4),
                      blurRadius: 8 + _pulseController.value * 8,
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _formatDuration(_seconds),
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _stopRecording,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 20),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        if (_isSending) return;
        _startRecording();
      },
      child: Tooltip(
        message: 'Tocar para grabar voz',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: _isSending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Icons.mic,
                  color: Colors.grey,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
