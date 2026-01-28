import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_assistant_service.dart';
import '../models/app_theme.dart';

/// Diálogo del asistente de voz
class VoiceAssistantDialog extends ConsumerStatefulWidget {
  final AppTheme appTheme;

  const VoiceAssistantDialog({
    Key? key,
    required this.appTheme,
  }) : super(key: key);

  @override
  ConsumerState<VoiceAssistantDialog> createState() => _VoiceAssistantDialogState();
}

class _VoiceAssistantDialogState extends ConsumerState<VoiceAssistantDialog> {
  final VoiceAssistantService _assistant = VoiceAssistantService();
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String _transcription = '';
  String _response = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeAssistant();
  }

  Future<void> _initializeAssistant() async {
    await _assistant.initialize();
    final available = await _assistant.isAvailable();
    if (!available && mounted) {
      setState(() {
        _error = 'El reconocimiento de voz no está disponible en este dispositivo';
      });
    }
  }

  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _isProcessing = false;
      _transcription = '';
      _response = '';
      _error = null;
    });

    try {
      print('🎤 [VoiceDialog] Iniciando escucha...');
      final stream = _assistant.startListening();
      String? finalTranscription;
      
      await for (final text in stream) {
        print('📝 [VoiceDialog] Texto recibido del stream: "$text"');
        
        // Verificar si es un marcador de error
        if (text == '__ERROR__') {
          print('❌ [VoiceDialog] Error detectado en el stream');
          if (mounted) {
            setState(() {
              _error = 'Error de reconocimiento de voz. Por favor, verifica tu conexión a internet y los permisos del micrófono, e intenta de nuevo.';
              _isListening = false;
            });
          }
          return; // Salir sin procesar
        }
        
        if (mounted) {
          setState(() {
            _transcription = text;
            finalTranscription = text; // Guardar el último texto
          });
        }
      }
      
      print('🔚 [VoiceDialog] Stream terminado. Transcripción final: "$finalTranscription"');

      // Cuando termine de escuchar, procesar la pregunta
      final questionToProcess = finalTranscription ?? _transcription;
      print('❓ [VoiceDialog] Pregunta a procesar: "$questionToProcess"');
      
      if (mounted && questionToProcess.isNotEmpty && questionToProcess.trim().isNotEmpty && questionToProcess != '__ERROR__') {
        print('🔄 [VoiceDialog] Iniciando procesamiento de IA...');
        setState(() {
          _isProcessing = true;
        });

        final response = await _assistant.getAIResponse(questionToProcess);
        print('💬 [VoiceDialog] Respuesta recibida: "$response"');
        
        if (mounted) {
          setState(() {
            _response = response;
            _isProcessing = false;
          });

          // Hablar la respuesta
          print('🗣️ [VoiceDialog] Iniciando síntesis de voz...');
          await _assistant.speak(response);
          print('✅ [VoiceDialog] Síntesis de voz completada');
        }
      } else {
        print('⚠️ [VoiceDialog] No hay transcripción para procesar');
        if (mounted) {
          setState(() {
            _error = 'No se pudo reconocer tu voz. Por favor, intenta de nuevo o verifica tu conexión a internet.';
            _isListening = false;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ [VoiceDialog] Error: $e');
      print('📚 [VoiceDialog] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isListening = false;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _stopListening() {
    _assistant.stopListening();
    setState(() {
      _isListening = false;
    });
  }

  void _stopSpeaking() {
    _assistant.stopSpeaking();
    setState(() {
      _isSpeaking = false;
    });
  }

  @override
  void dispose() {
    _assistant.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.appTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Row(
              children: [
                Icon(
                  Icons.mic,
                  color: widget.appTheme.accent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Asistente de Voz',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: widget.appTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: widget.appTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Estado de escucha
            if (_isListening)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Escuchando...',
                      style: TextStyle(
                        color: widget.appTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_transcription.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _transcription,
                        style: TextStyle(
                          color: widget.appTheme.textSecondary,
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

            // Procesando
            if (_isProcessing)
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      'Procesando tu pregunta...',
                      style: TextStyle(
                        color: widget.appTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

            // Respuesta
            if (_response.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.appTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.smart_toy,
                          color: widget.appTheme.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Respuesta:',
                          style: TextStyle(
                            color: widget.appTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _response,
                      style: TextStyle(
                        color: widget.appTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Botones de control
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isListening && !_isProcessing)
                  ElevatedButton.icon(
                    onPressed: _startListening,
                    icon: const Icon(Icons.mic, size: 20),
                    label: const Text('Hablar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.appTheme.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  )
                else if (_isListening)
                  ElevatedButton.icon(
                    onPressed: _stopListening,
                    icon: const Icon(Icons.stop, size: 20),
                    label: const Text('Detener'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                if (_isSpeaking) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _stopSpeaking,
                    icon: const Icon(Icons.volume_off, size: 20),
                    label: const Text('Silenciar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 16),

            // Información
            Text(
              'Pregunta sobre GlobalChat, bots Anope, comandos, radio, etc.',
              style: TextStyle(
                color: widget.appTheme.textSecondary,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
