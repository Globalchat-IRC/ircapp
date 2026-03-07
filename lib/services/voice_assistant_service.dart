import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../utils/platform_utils.dart';
import 'web_speech_stub.dart'
    if (dart.library.html) 'web_speech.dart' as web_stt;
import '../config/debug_config.dart';

/// Servicio de asistente de voz con IA para ayudar con dudas sobre GlobalChat y Anope
class VoiceAssistantService {
  static final VoiceAssistantService _instance = VoiceAssistantService._internal();
  factory VoiceAssistantService() => _instance;
  VoiceAssistantService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isListening = false;
  bool _isSpeaking = false;
  String _transcription = ''; // Guardar transcripción actual
  String? _localeId; // Locale detectado para STT
  StreamController<String>? _transcriptionController;
  StreamController<String>? _responseController;
  
  // Configuración de Groq
  String? _openAiApiKey = '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';
  final String _model = 'openai/gpt-oss-120b'; // Modelo GPT-OSS 120B
  String _apiBaseUrl = 'https://api.groq.com/openai/v1'; // API de Groq compatible con OpenAI
  
  // Callback para manejar errores de STT
  void Function(Object)? _onSttError;
  void Function(String)? _onSttStatus;
  
  /// Inicializar el servicio
  Future<void> initialize() async {
    // Configurar API key de Groq si no está configurada
    _openAiApiKey ??= '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';
    
    // Asegurar que _apiBaseUrl esté configurado
    _apiBaseUrl = _apiBaseUrl.isEmpty ? 'https://api.groq.com/openai/v1' : _apiBaseUrl;
    
    debugLog('🔧 [VoiceAssistant] Inicializado con modelo: $_model');
    debugLog('🔧 [VoiceAssistant] API URL: $_apiBaseUrl');
    
    // Configurar TTS (por defecto español)
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    
    // Configurar callbacks de TTS
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    
    _tts.setErrorHandler((msg) {
      debugLog('Error TTS: $msg');
      _isSpeaking = false;
    });
    
    // Inicializar STT con los callbacks configurados
    final hasSpeech = await _speech.initialize(
      onError: _onSttError,
      onStatus: _onSttStatus,
    );

    debugLog('🔧 [VoiceAssistant] STT inicializado: hasSpeech=$hasSpeech');

    // Detectar locale del sistema para usarlo en listen()
    try {
      final systemLocale = await _speech.systemLocale();
      _localeId = systemLocale?.localeId;
      debugLog('🌍 [VoiceAssistant] Locale STT del sistema: $_localeId');
    } catch (e) {
      debugLog('⚠️ [VoiceAssistant] No se pudo obtener systemLocale: $e');
      _localeId ??= 'es-ES';
    }
  }
  
  /// Configurar API key de OpenAI
  void setOpenAiApiKey(String? apiKey) {
    _openAiApiKey = apiKey;
  }
  
  /// Verificar si el reconocimiento de voz está disponible
  Future<bool> isAvailable() async {
    if (PlatformUtils.isWeb) {
      // En web usar la API nativa del navegador
      return await web_stt.isWebSpeechAvailable();
    }
    // En nativo, usar el estado real del permiso
    return _speech.hasPermission;
  }
  
  /// Iniciar escucha de voz
  Stream<String> startListening() {
    _transcriptionController = StreamController<String>();
    _transcription = ''; // Resetear transcripción
    
    // En web, usar la Web Speech API nativa
    if (PlatformUtils.isWeb) {
      final localeToUse = _localeId ?? 'es-ES';
      debugLog('🎤 [VoiceAssistant] (Web) Escuchando con locale: $localeToUse');
      return web_stt.startWebSpeech(localeToUse);
    }
    
    // Configurar callbacks de error y status si no están configurados
    // IMPORTANTE: Estos callbacks se ejecutan cuando hay errores durante listen()
    _onSttError ??= (error) {
      debugLog('❌ [VoiceAssistant] Error STT en listen: $error');
      if (_isListening && _transcriptionController != null && !_transcriptionController!.isClosed) {
        _isListening = false;
        try {
          // Enviar un marcador especial de error al stream
          _transcriptionController?.add('__ERROR__');
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_transcriptionController != null && !_transcriptionController!.isClosed) {
              debugLog('🔒 [VoiceAssistant] Cerrando stream por error STT...');
              _transcriptionController?.close();
              _transcriptionController = null;
              debugLog('✅ [VoiceAssistant] Stream cerrado después de error STT');
            }
          });
        } catch (e) {
          debugLog('⚠️ [VoiceAssistant] Error al enviar marcador de error: $e');
        }
      }
    };
    
    _onSttStatus ??= (status) {
      debugLog('📊 [VoiceAssistant] Status STT: $status');
      // Si el estado cambia a "done" o "notListening" sin resultado final, cerrar el stream
      if ((status == 'done' || status == 'notListening') && _isListening && _transcriptionController != null && !_transcriptionController!.isClosed) {
        debugLog('⚠️ [VoiceAssistant] Status cambió a $status pero aún estaba escuchando');
        // Solo cerrar si no hay transcripción válida
        if (_transcription.isEmpty || _transcription.trim().isEmpty) {
          debugLog('⚠️ [VoiceAssistant] No hay transcripción válida, cerrando stream...');
          _isListening = false;
          try {
            _transcriptionController?.add('__ERROR__');
          } catch (e) {
            debugLog('⚠️ [VoiceAssistant] Error al enviar error: $e');
          }
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_transcriptionController != null && !_transcriptionController!.isClosed) {
              _transcriptionController?.close();
              _transcriptionController = null;
              debugLog('✅ [VoiceAssistant] Stream cerrado por cambio de status');
            }
          });
        }
      }
    };
    
    if (!_isListening) {
      _isListening = true;
      // Usar el locale detectado, con fallback a español
      final localeToUse = _localeId ?? 'es-ES';
      debugLog('🎤 [VoiceAssistant] Escuchando con locale: $localeToUse');
      _speech.listen(
        onResult: (result) {
          debugLog('🎤 [VoiceAssistant] Reconocido: "${result.recognizedWords}" (final: ${result.finalResult})');
          // Guardar transcripción actual
          _transcription = result.recognizedWords;
          
          if (result.finalResult) {
            final finalText = result.recognizedWords.trim();
            debugLog('✅ [VoiceAssistant] Resultado final recibido: "$finalText"');
            if (finalText.isNotEmpty) {
              _transcriptionController?.add(finalText);
            }
            debugLog('🛑 [VoiceAssistant] Deteniendo escucha...');
            _speech.stop();
            _isListening = false;
            // Cerrar el stream inmediatamente después de agregar el resultado final
            Future.delayed(const Duration(milliseconds: 50), () {
              if (_transcriptionController != null && !_transcriptionController!.isClosed) {
                debugLog('🔒 [VoiceAssistant] Cerrando stream controller...');
                _transcriptionController?.close();
                _transcriptionController = null;
                debugLog('✅ [VoiceAssistant] Stream cerrado correctamente');
              }
            });
          } else {
            // Enviar resultados parciales
            if (_transcriptionController != null && !_transcriptionController!.isClosed) {
              _transcriptionController?.add(result.recognizedWords);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        localeId: localeToUse,
        listenOptions: stt.SpeechListenOptions(
          cancelOnError: true,
          partialResults: true,
        ),
        onSoundLevelChange: (level) {
          // Opcional: mostrar nivel de sonido
        },
      );
      debugLog('🎤 [VoiceAssistant] Iniciando escucha...');
    }
    
    return _transcriptionController!.stream;
  }
  
  /// Detener escucha de voz
  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
      _transcriptionController?.close();
      _transcriptionController = null;
    }
  }
  
  /// Verificar si está escuchando
  bool get isListening => _isListening;
  
  /// Verificar si está hablando
  bool get isSpeaking => _isSpeaking;
  
  /// Obtener respuesta de la IA
  Future<String> getAIResponse(String question) async {
    try {
      debugLog('🤖 [VoiceAssistant] Obteniendo respuesta para: "$question"');
      
      // Si no hay API key, usar respuestas predefinidas
      if (_openAiApiKey == null || _openAiApiKey!.isEmpty) {
        debugLog('⚠️ [VoiceAssistant] No hay API key, usando respuesta predefinida');
        return _getPredefinedResponse(question);
      }
      
      final apiUrl = '$_apiBaseUrl/chat/completions';
      debugLog('🌐 [VoiceAssistant] Llamando a: $apiUrl');
      debugLog('🤖 [VoiceAssistant] Modelo: $_model');
      
      // Llamar a Groq API (compatible con OpenAI)
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_openAiApiKey',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content': _getSystemPrompt(),
            },
            {
              'role': 'user',
              'content': question,
            },
          ],
          // Preferimos respuestas más cortas y controladas (evita “manuales” largos)
          'temperature': 0.3,
          'max_completion_tokens': 600,
          'top_p': 1,
          'reasoning_effort': 'medium',
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 30));
      
      debugLog('📡 [VoiceAssistant] Respuesta recibida: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugLog('✅ [VoiceAssistant] Datos recibidos: ${data.keys}');
        
        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']['content'] as String;
          debugLog('💬 [VoiceAssistant] Respuesta: "$content"');
          return content.trim();
        } else {
          debugLog('⚠️ [VoiceAssistant] No hay choices en la respuesta');
          return _getPredefinedResponse(question);
        }
      } else {
        debugLog('❌ [VoiceAssistant] Error API: ${response.statusCode} - ${response.body}');
        return _getPredefinedResponse(question);
      }
    } catch (e, stackTrace) {
      debugLog('❌ [VoiceAssistant] Error obteniendo respuesta de IA: $e');
      debugLog('📚 [VoiceAssistant] Stack trace: $stackTrace');
      return _getPredefinedResponse(question);
    }
  }
  
  /// Obtener prompt del sistema con información sobre GlobalChat y Anope
  String _getSystemPrompt() {
    return '''Eres un asistente experto en IRC y en la red GlobalChat.

REGLAS DE RESPUESTA (muy importante):
- Responde SIEMPRE en español.
- Sé breve por defecto (3-6 líneas). Solo escribe una guía larga si el usuario pide “detallado/paso a paso”.
- NO inventes nombres de bots, canales o URLs. Si no estás seguro, dilo y sugiere preguntar en #globalchat.
- Para “tickets/soporte”, usa EXCLUSIVAMENTE la información de la sección TICKETS/CAU.

Sobre GlobalChat:

CONEXIÓN:
- Servidores distribuidos con alta disponibilidad
- Puedes conectarte con cualquier cliente IRC (mIRC, HexChat, irssi, etc.)
- Host: irc.globalchat.net
- Puerto: 6667 (texto) o 6697 (SSL)

SERVICIOS ANOPE:
- NickServ: Registro y gestión de nicks
- ChanServ: Control de canales
- MemoServ: Mensajería interna
- BotServ: Bots de ayuda
- HostServ: Vhosts personalizados

Comandos principales de Anope:
  * /msg NickServ REGISTER <contraseña> <email> - Registrar una cuenta
  * /msg NickServ IDENTIFY <contraseña> - Identificarse
  * /msg NickServ SET PASSWORD <nueva_contraseña> - Cambiar contraseña
  * /msg NickServ INFO <nick> - Ver información de un nick
  * /msg ChanServ REGISTER <#canal> - Registrar un canal
  * /msg ChanServ OP <#canal> <nick> - Dar operador a un usuario
  * /msg MemoServ SEND <nick> <mensaje> - Enviar memo
  * /msg MemoServ READ - Leer memos
  * /msg HostServ SET <host> - Cambiar hostname
  * /msg BotServ ASSIGN <#canal> <bot> - Asignar bot a canal

BOTS DE GLOBALCHAT:
- RadioBot_GC: Radio y peticiones de música
- Ayudante: Bot de ayuda general
- Idle: Bot de gestión de inactividad
- SeenAllBot: Bot de información de usuarios
- Stats: Bot de estadísticas
- YoutubeBot: Bot para compartir videos de YouTube

CANALES TEMÁTICOS:
- Canales principales: #globalchat, #nuestrasvoces, #soundmusic, #urbanflow
- Cientos de canales de ocio, tecnología, idiomas, videojuegos, etc.

TICKETS / CAU (SOPORTE):
- Canales de ayuda: #ayuda y #cau
- Crear ticket por web: http://soporte.globalchat.org/index.php?a=add
- Si preguntan “cómo abrir un ticket”, responde con esos datos y una frase corta de qué información incluir (nick, problema, capturas/logs).

RADIOS:
- Transmisión de música en canales dedicados
- Los usuarios pueden solicitar canciones mediante RadioBot_GC
- Estaciones disponibles: NuestrasVoces, SoundMusic, UrbanFlow
- Se puede escuchar la stream a través del propio IRC o mediante URLs externas

ROLES Y PERMISOS:
- Operadores (@): Administradores de canal
- Halfops (%): Operadores con permisos limitados
- Voice (+): Usuarios con voz en canal
- Usuarios normales: Sin permisos especiales
- Flags de canal que permiten gestionar usuarios, modos, bans, etc.

NETIQUETA:
- Normas de conducta y buenas prácticas para mantener un ambiente respetuoso y agradable

FUNCIONALIDADES ADICIONALES:
- Videollamadas: Disponible para usuarios verificados o con más de 7 días registrados
- Compartir archivos: Se pueden subir imágenes y videos
- Emojis: Soporte completo de emojis y emoticonos animados

Responde de forma clara, concisa y en español. Si no sabes algo, admítelo y sugiere consultar la documentación oficial o preguntar en el canal #globalchat.''';
  }
  
  /// Respuestas predefinidas cuando no hay API key de OpenAI
  String _getPredefinedResponse(String question) {
    final lowerQuestion = question.toLowerCase();
    
    // Registro
    if (lowerQuestion.contains('registrar') || lowerQuestion.contains('register')) {
      return 'Para registrar una cuenta en GlobalChat, usa el comando: /msg NickServ REGISTER seguido de tu contraseña y email. Por ejemplo: /msg NickServ REGISTER miPassword123 mi@email.com';
    }
    
    // Identificarse
    if (lowerQuestion.contains('identificar') || lowerQuestion.contains('login') || lowerQuestion.contains('iniciar sesión')) {
      return 'Para identificarte, usa: /msg NickServ IDENTIFY seguido de tu contraseña. Por ejemplo: /msg NickServ IDENTIFY miPassword123';
    }
    
    // Cambiar contraseña
    if (lowerQuestion.contains('contraseña') || lowerQuestion.contains('password') || lowerQuestion.contains('cambiar contraseña')) {
      return 'Para cambiar tu contraseña, usa: /msg NickServ SET PASSWORD seguido de tu nueva contraseña. Debes estar identificado primero.';
    }
    
    // Información de nick
    if (lowerQuestion.contains('info') || lowerQuestion.contains('información')) {
      return 'Para ver información de un nick, usa: /msg NickServ INFO seguido del nick. Por ejemplo: /msg NickServ INFO nombreUsuario';
    }
    
    // Registrar canal
    if (lowerQuestion.contains('registrar canal') || lowerQuestion.contains('register channel')) {
      return 'Para registrar un canal, primero debes ser operador del canal. Luego usa: /msg ChanServ REGISTER seguido del nombre del canal. Por ejemplo: /msg ChanServ REGISTER #micanal';
    }
    
    // Dar operador
    if (lowerQuestion.contains('operador') || lowerQuestion.contains('op') || lowerQuestion.contains('dar op')) {
      return 'Para dar operador a un usuario en un canal, usa: /msg ChanServ OP seguido del canal y el nick. Por ejemplo: /msg ChanServ OP #micanal nombreUsuario';
    }
    
    // Memos
    if (lowerQuestion.contains('memo')) {
      return 'Para enviar un memo, usa: /msg MemoServ SEND seguido del nick y el mensaje. Para leer memos: /msg MemoServ READ';
    }
    
    // Hostname
    if (lowerQuestion.contains('host') || lowerQuestion.contains('hostname')) {
      return 'Para cambiar tu hostname, usa: /msg HostServ SET seguido del hostname deseado. Debes estar identificado.';
    }
    
    // Radio
    if (lowerQuestion.contains('radio')) {
      return 'GlobalChat tiene tres estaciones de radio: NuestrasVoces, SoundMusic y UrbanFlow. Puedes escucharlas desde el panel de radio en la aplicación.';
    }
    
    // Videollamadas
    if (lowerQuestion.contains('video') || lowerQuestion.contains('videollamada')) {
      return 'Las videollamadas están disponibles para usuarios que hayan verificado su email o tengan más de 7 días registrados. Puedes iniciar una videollamada desde el menú del canal.';
    }
    
    // Respuesta por defecto
    return 'Lo siento, no tengo información específica sobre esa pregunta. Puedes consultar la documentación de GlobalChat o preguntar en el canal #globalchat. Si tienes una API key de OpenAI configurada, podré darte respuestas más detalladas.';
  }
  
  /// Hablar una respuesta (text-to-speech)
  Future<void> speak(String text) async {
    if (_isSpeaking) {
      await _tts.stop();
    }
    
    _isSpeaking = true;
    await _tts.speak(text);
  }
  
  /// Detener habla
  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }
  
  /// Procesar pregunta completa: escuchar, obtener respuesta, y hablar
  Future<String> processQuestion() async {
    try {
      // Escuchar
      final transcriptionStream = startListening();
      String? question;
      
      await for (final text in transcriptionStream) {
        question = text;
        if (!_isListening) break; // Se detuvo la escucha
      }
      
      if (question == null || question.isEmpty) {
        return 'No pude entender tu pregunta. Por favor, intenta de nuevo.';
      }
      
      // Obtener respuesta de IA
      final response = await getAIResponse(question);
      
      // Hablar respuesta
      await speak(response);
      
      return response;
    } catch (e) {
      debugLog('Error procesando pregunta: $e');
      return 'Ocurrió un error al procesar tu pregunta. Por favor, intenta de nuevo.';
    }
  }
  
  /// Limpiar recursos
  void dispose() {
    stopListening();
    stopSpeaking();
    _transcriptionController?.close();
    _responseController?.close();
  }
}
