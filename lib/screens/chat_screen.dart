import 'dart:ui' as ui;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/irc_message.dart';
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../services/irc_service.dart';
import 'login_screen.dart';
import '../widgets/animated_topic_text.dart';
import '../widgets/radio_controls.dart';

// Widget genérico para botones animados
class AnimatedServiceButton extends StatefulWidget {
  final VoidCallback onPressed;
  final AppTheme appTheme;
  final String tooltip;
  final String emoji;
  final String label;

  const AnimatedServiceButton({
    Key? key,
    required this.onPressed,
    required this.appTheme,
    required this.tooltip,
    required this.emoji,
    required this.label,
  }) : super(key: key);

  @override
  State<AnimatedServiceButton> createState() => _AnimatedServiceButtonState();
}

class _AnimatedServiceButtonState extends State<AnimatedServiceButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) {
            setState(() => _isPressed = false);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isPressed ? 0.95 : (_isHovered ? _pulseAnimation.value : 1.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isHovered
                          ? [
                              widget.appTheme.accent,
                              widget.appTheme.primary,
                            ]
                          : [
                              widget.appTheme.primary.withOpacity(0.7),
                              widget.appTheme.secondary.withOpacity(0.7),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: _isHovered
                        ? [
                            BoxShadow(
                              color: widget.appTheme.accent.withOpacity(0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: widget.appTheme.primary.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 1,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedRotation(
                        turns: _isHovered ? 0.1 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Text(
                          widget.emoji,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.label,
                        style: TextStyle(
                          color: widget.appTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Intent para pegar imágenes
class PasteImageIntent extends Intent {
  const PasteImageIntent();
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _channelController = TextEditingController();
  late IRCService _ircService;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _ircService = ref.read(ircServiceProvider);
    
    print('🎬 [ChatScreen] Initialized');
    print('🎬 [ChatScreen] isConnected=${_ircService.isConnected}');
    
    // Listen for user list changes
    _ircService.addUserListListener(_onUserListChanged);
    
    // Listen for topic changes
    _ircService.addTopicListener(_onTopicChanged);
    
    // Get the channel from provider (was set in LoginScreen)
    final channel = ref.read(currentChannelProvider);
    print('🎬 [ChatScreen] Got channel from provider: $channel');
    
    // Únete después del primer frame y esperar a que el servidor termine de registrar al usuario
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetChannel = (channel != null && channel.isNotEmpty) ? channel : '#general';
      if (channel == null || channel.isEmpty) {
      print('⚠️  [ChatScreen] No channel specified, using #general');
      }
      
      // Esperar un poco más para asegurar que el servidor haya terminado de registrar al usuario
      // El servidor envía el 001 (Welcome) cuando el usuario está registrado
      print('📍 [ChatScreen] Waiting for server registration before joining channel: $targetChannel');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        print('📍 [ChatScreen] Joining channel after delay: $targetChannel');
        _joinChannel(targetChannel);
      });
    });
  }

  void _onUserListChanged(String channel) {
    print('👥 _onUserListChanged called for: $channel');
    if (mounted) {
      print('  🔄 Scheduling Riverpod update post-frame');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
      ref.read(channelsProvider.notifier).updateChannels();
        setState(() {
          print('  🔄 setState after post-frame');
        });
      });
    }
  }

  void _onTopicChanged(String channel) {
    print('📌 _onTopicChanged called for: $channel');
    if (mounted) {
      print('  🔄 Scheduling Riverpod update post-frame for topic');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(channelsProvider.notifier).updateChannels();
      setState(() {
          print('  🔄 setState after post-frame for topic');
        });
      });
    }
  }

  @override
  void dispose() {
    _ircService.removeUserListListener(_onUserListChanged);
    _ircService.removeTopicListener(_onTopicChanged);
    _messageController.dispose();
    _channelController.dispose();
    super.dispose();
  }

  void _joinChannel(String channel) {
    if (channel.isEmpty) return;
    
    // Normalizar el nombre del canal (asegurar que tenga #)
    String normalizedChannel = channel.trim();
    
    // Remover ':' si está al inicio
    if (normalizedChannel.startsWith(':')) {
      normalizedChannel = normalizedChannel.substring(1).trim();
    }
    
    // Remover # duplicados al inicio
    while (normalizedChannel.startsWith('##')) {
      normalizedChannel = normalizedChannel.substring(1);
    }
    
    // Asegurar que empiece con # (solo uno)
    if (!normalizedChannel.startsWith('#')) {
      normalizedChannel = '#$normalizedChannel';
    }
    
    // Normalizar a minúsculas para consistencia
    normalizedChannel = normalizedChannel.toLowerCase();
    
    print('🔍 [DEBUG] 🚪 Joining channel: "$channel" -> normalized: "$normalizedChannel"');
    _ircService.joinChannel(normalizedChannel);
    ref.read(currentChannelProvider.notifier).state = normalizedChannel;
    print('🔍 [DEBUG] ✅ Channel set in provider: $normalizedChannel');
    _channelController.clear();
    
    // Force UI update
    print('🔍 [DEBUG] 🔄 Forcing channels provider update...');
    ref.read(channelsProvider.notifier).updateChannels();
    
    // Also update after delays to catch late responses
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        print('🔍 [DEBUG] 🔄 Secondary channels update (800ms)');
        ref.read(channelsProvider.notifier).updateChannels();
      }
    });
    
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        print('🔍 [DEBUG] 🔄 Tertiary channels update (2000ms)');
        ref.read(channelsProvider.notifier).updateChannels();
      }
    });
  }

  void _sendMessage() {
    final channel = ref.read(currentChannelProvider);
    if (channel == null || _messageController.text.isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();
    
    // Detectar comandos que empiezan con /
    if (message.startsWith('/')) {
      _handleCommand(message);
      return;
    }

    // Normalizar el nombre del canal antes de enviar
    final normalizedChannel = channel.toLowerCase();
    
    // Si el canal no empieza con #, es un query (mensaje privado)
    if (normalizedChannel.startsWith('#')) {
      _ircService.sendMessage(normalizedChannel, message);
    } else {
      // Es un query, enviar mensaje privado
      _ircService.sendPrivateMessage(normalizedChannel, message);
    }
    
    // Trigger UI update
    ref.read(messagesProvider.notifier);
  }

  void _handleCommand(String command) {
    final parts = command.substring(1).split(' '); // Remover el / inicial
    if (parts.isEmpty) return;
    
    final cmd = parts[0].toLowerCase();
    final args = parts.length > 1 ? parts.sublist(1) : <String>[];
    
    switch (cmd) {
      case 'query':
        if (args.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Uso: /query <nick> [mensaje]'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final nick = args[0].trim();
        if (nick.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor ingresa un nick válido'),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        
        final message = args.length > 1 ? args.sublist(1).join(' ') : '';
        
        // El query es el nick en minúsculas (sin #)
        final queryNick = nick.toLowerCase();
        
        // Asegurarse de que el query existe en los canales
        if (!_ircService.allChannels.containsKey(queryNick)) {
          _ircService.allChannels[queryNick] = IRCChannel(name: queryNick);
          print('📝 [Query] Creado query para: $queryNick');
        }
        
        // Cambiar al query (mensaje privado)
        ref.read(currentChannelProvider.notifier).state = queryNick;
        
        // Si hay un mensaje, enviarlo como PRIVMSG al nick
        if (message.isNotEmpty) {
          _ircService.sendPrivateMessage(nick, message);
        }
        
        // Forzar actualización de la UI
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            ref.read(channelsProvider.notifier).updateChannels();
            setState(() {});
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Abriendo mensaje privado con $nick...'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
        
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Comando desconocido: /$cmd'),
            duration: const Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      print('🔍 Iniciando selección de imagen o video...');
      
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'webm', 'mov'],
        allowMultiple: false,
        dialogTitle: 'Seleccionar imagen o video',
        withData: true, // Obtener también los bytes
      );

      print('🔍 Resultado del file picker: ${result != null ? "no null" : "null"}');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('🔍 Archivo seleccionado:');
        print('  - name: ${file.name}');
        print('  - path: ${file.path}');
        print('  - bytes: ${file.bytes != null ? "${file.bytes!.length} bytes" : "null"}');
        print('  - size: ${file.size}');
        
        String? filePath = file.path;
        
        // Si no hay path pero hay bytes, guardar en archivo temporal
        if ((filePath == null || filePath.isEmpty) && file.bytes != null) {
          final tempDir = Directory.systemTemp;
          final extension = file.name.split('.').last;
          final tempFile = File('${tempDir.path}/picked_image_${DateTime.now().millisecondsSinceEpoch}.$extension');
          await tempFile.writeAsBytes(file.bytes!);
          filePath = tempFile.path;
          print('✅ Imagen guardada en archivo temporal: $filePath');
        }
        
        if (filePath != null && filePath.isNotEmpty) {
          final mediaFile = File(filePath);
          
          // Verificar que el archivo existe
          if (await mediaFile.exists()) {
            print('✅ Archivo existe, procesando...');
            
            // Detectar si es imagen o video
            final extension = file.name.split('.').last.toLowerCase();
            final isVideo = ['mp4', 'webm', 'mov'].contains(extension);
            
            if (isVideo) {
              await _processAndSendVideo(mediaFile);
            } else {
              await _processAndSendImage(mediaFile);
            }
          } else {
            print('❌ El archivo no existe: $filePath');
            throw Exception('El archivo seleccionado no existe: $filePath');
          }
        } else {
          print('❌ No se pudo obtener la ruta del archivo');
          throw Exception('No se pudo obtener la ruta del archivo seleccionado');
        }
      } else {
        print('ℹ️ No se seleccionó ningún archivo (usuario canceló)');
      }
    } catch (e, stackTrace) {
      print('❌ Error al seleccionar imagen: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              onPressed: _pickAndSendImage,
            ),
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSendToCloudinary(Uint8List imageBytes, String mimeType, String channel) async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Subiendo imagen a Cloudinary...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }
    
    try {
      // Subir a Cloudinary
      final imageUrl = await _uploadImageToCloudinary(imageBytes, mimeType);
      
      if (imageUrl != null) {
        final normalizedChannel = channel.toLowerCase();
        await Future.delayed(const Duration(milliseconds: 300));
        // Enviar solo la URL (sin prefijo [Imagen] para que se detecte automáticamente)
        _ircService.sendMessage(normalizedChannel, imageUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Imagen subida y URL enviada')),
          );
        }
      } else {
        throw Exception('No se pudo subir la imagen a Cloudinary');
      }
    } catch (e) {
      print('❌ Error al subir imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _uploadAndSendVideoToCloudinary(Uint8List videoBytes, String mimeType, String channel) async {
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Subiendo video a Cloudinary...'),
            ],
          ),
          duration: Duration(seconds: 60),
        ),
      );
    }
    
    try {
      // Subir a Cloudinary
      final videoUrl = await _uploadVideoToCloudinary(videoBytes, mimeType);
      
      if (videoUrl != null) {
        final normalizedChannel = channel.toLowerCase();
        await Future.delayed(const Duration(milliseconds: 300));
        // Enviar solo la URL (sin prefijo para que se detecte automáticamente)
        _ircService.sendMessage(normalizedChannel, videoUrl);
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Video subido y URL enviada')),
          );
        }
      } else {
        throw Exception('No se pudo subir el video a Cloudinary');
      }
    } catch (e) {
      print('❌ Error al subir video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir video: ${e.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<String?> _uploadImageToCloudinary(Uint8List imageBytes, String mimeType) async {
    try {
      // Configuración de Cloudinary (del plugin web)
      const cloudName = 'datdq7xkz';
      const uploadPreset = 'ml_default';
      const maxSize = 10 * 1024 * 1024; // 10MB
      
      // Verificar tamaño
      if (imageBytes.length > maxSize) {
        print('❌ Imagen demasiado grande: ${(imageBytes.length / 1024 / 1024).toStringAsFixed(2)} MB (máximo 10MB)');
        return null;
      }
      
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      // Crear el body como multipart
      final request = http.MultipartRequest('POST', uri);
      
      // Añadir la imagen
      final extension = mimeType.split('/')[1];
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'image.$extension',
        ),
      );
      
      // Añadir el upload preset
      request.fields['upload_preset'] = uploadPreset;
      
      print('📤 Subiendo imagen a Cloudinary... (${(imageBytes.length / 1024).toStringAsFixed(2)} KB)');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['secure_url'] != null) {
          final imageUrl = jsonResponse['secure_url'] as String;
          print('✅ Imagen subida a Cloudinary: $imageUrl');
          return imageUrl;
        } else {
          print('❌ Error en respuesta de Cloudinary: ${jsonResponse['error']}');
          return null;
        }
      } else {
        print('❌ Error HTTP al subir imagen: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al subir imagen a Cloudinary: $e');
      return null;
    }
  }

  Future<String?> _uploadVideoToCloudinary(Uint8List videoBytes, String mimeType) async {
    try {
      // Configuración de Cloudinary (del plugin web)
      const cloudName = 'datdq7xkz';
      const uploadPreset = 'ml_default';
      const maxSize = 100 * 1024 * 1024; // 100MB para videos
      
      // Verificar tamaño
      if (videoBytes.length > maxSize) {
        print('❌ Video demasiado grande: ${(videoBytes.length / 1024 / 1024).toStringAsFixed(2)} MB (máximo 100MB)');
        return null;
      }
      
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/video/upload');
      
      // Crear el body como multipart
      final request = http.MultipartRequest('POST', uri);
      
      // Añadir el video
      final extension = mimeType.split('/')[1];
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          videoBytes,
          filename: 'video.$extension',
        ),
      );
      
      // Añadir el upload preset
      request.fields['upload_preset'] = uploadPreset;
      
      print('📤 Subiendo video a Cloudinary... (${(videoBytes.length / 1024 / 1024).toStringAsFixed(2)} MB)');
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['secure_url'] != null) {
          final videoUrl = jsonResponse['secure_url'] as String;
          print('✅ Video subido a Cloudinary: $videoUrl');
          return videoUrl;
        } else {
          print('❌ Error en respuesta de Cloudinary: ${jsonResponse['error']}');
          return null;
        }
      } else {
        print('❌ Error HTTP al subir video: ${response.statusCode}');
        print('❌ Respuesta: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Excepción al subir video a Cloudinary: $e');
      return null;
    }
  }

  Future<void> _checkClipboardForImage() async {
    // Verificar periódicamente si hay una imagen en el portapapeles
    // Esto se puede mejorar con un listener más directo
  }

  Future<void> _pasteImageFromClipboard() async {
    try {
      if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
        // Intentar obtener imagen del portapapeles
        final imageData = await Pasteboard.image;
        
        if (imageData != null) {
          print('✅ Imagen encontrada en el portapapeles');
          
          // Convertir Uint8List a File temporal
          final tempDir = Directory.systemTemp;
          final tempFile = File('${tempDir.path}/pasted_image_${DateTime.now().millisecondsSinceEpoch}.png');
          await tempFile.writeAsBytes(imageData);
          
          await _processAndSendImage(tempFile);
          
          // Limpiar archivo temporal después de un delay
          Future.delayed(const Duration(seconds: 5), () {
            try {
              tempFile.deleteSync();
            } catch (e) {
              print('⚠️ No se pudo eliminar archivo temporal: $e');
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No hay imagen en el portapapeles'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error al pegar imagen: $e');
      print('❌ Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al pegar imagen: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _processAndSendImage(File imageFile) async {
    try {
      final channel = ref.read(currentChannelProvider);
      if (channel == null) return;

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Comprimiendo y procesando imagen...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Leer la imagen
      final originalBytes = await imageFile.readAsBytes();
      final originalSize = originalBytes.length;
      print('📸 Tamaño original de la imagen: ${(originalSize / 1024).toStringAsFixed(2)} KB');
      
      // Detectar el tipo MIME
      final extension = imageFile.path.split('.').last.toLowerCase();
      String mimeType = 'image/png';
      if (extension == 'jpg' || extension == 'jpeg') {
        mimeType = 'image/jpeg';
      } else if (extension == 'gif') {
        mimeType = 'image/gif';
      } else if (extension == 'webp') {
        mimeType = 'image/webp';
      }

      // Subir TODAS las imágenes a Cloudinary para evitar flood protection
      // IRC tiene límites estrictos y cualquier imagen en base64 causa flood
      await _uploadAndSendToCloudinary(originalBytes, mimeType, channel);
    } catch (e) {
      print('Error al procesar imagen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar imagen: $e')),
        );
      }
    }
  }

  Future<void> _processAndSendVideo(File videoFile) async {
    try {
      final channel = ref.read(currentChannelProvider);
      if (channel == null) return;

      // Mostrar indicador de carga
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Procesando video...'),
              ],
            ),
            duration: Duration(seconds: 60),
          ),
        );
      }

      // Leer el video
      final originalBytes = await videoFile.readAsBytes();
      final originalSize = originalBytes.length;
      print('🎥 Tamaño original del video: ${(originalSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      // Detectar el tipo MIME
      final extension = videoFile.path.split('.').last.toLowerCase();
      String mimeType = 'video/mp4';
      if (extension == 'webm') {
        mimeType = 'video/webm';
      } else if (extension == 'mov') {
        mimeType = 'video/quicktime';
      }

      // Subir TODOS los videos a Cloudinary
      await _uploadAndSendVideoToCloudinary(originalBytes, mimeType, channel);
    } catch (e) {
      print('Error al procesar video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar video: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  bool _isImageUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null) return false;
    
    // Detectar URLs de Cloudinary
    if (uri.host.contains('cloudinary.com') || uri.host.contains('res.cloudinary.com')) {
      return true;
    }
    
    final path = uri.path.toLowerCase();
    return path.endsWith('.jpg') || 
           path.endsWith('.jpeg') || 
           path.endsWith('.png') || 
           path.endsWith('.gif') || 
           path.endsWith('.webp') ||
           text.startsWith('data:image/');
  }

  bool _isVideoUrl(String text) {
    final uri = Uri.tryParse(text);
    if (uri == null) return false;
    
    // Detectar URLs de Cloudinary para videos
    if (uri.host.contains('cloudinary.com') || uri.host.contains('res.cloudinary.com')) {
      // Cloudinary puede servir videos, verificar si la URL contiene 'video' o tiene extensión de video
      final path = uri.path.toLowerCase();
      return path.contains('/video/') || 
             path.endsWith('.mp4') || 
             path.endsWith('.webm') || 
             path.endsWith('.mov');
    }
    
    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') || 
           path.endsWith('.webm') || 
           path.endsWith('.mov') ||
           text.startsWith('data:video/');
  }

  void _disconnect() {
    _ircService.disconnect();
    ref.read(currentNicknameProvider.notifier).state = null;
    ref.read(currentChannelProvider.notifier).state = null;
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Widget _buildLoadingScreen(AppTheme appTheme, String channelName) {
    return Scaffold(
      backgroundColor: appTheme.background,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              appTheme.primary.withOpacity(0.1),
              appTheme.secondary.withOpacity(0.1),
              appTheme.background,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo animado
              const _ModernLoadingSpinner(),
              const SizedBox(height: 40),
              // Texto de carga
              Text(
                'Conectando a $channelName...',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: appTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Cargando canal',
                style: TextStyle(
                  fontSize: 16,
                  color: appTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              // Indicador de progreso animado
              const SizedBox(
                width: 200,
                child: _LoadingProgressBar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nickname = ref.watch(currentNicknameProvider);
    final currentChannel = ref.watch(currentChannelProvider);
    final messages = ref.watch(messagesProvider);
    final channels = ref.watch(channelsProvider);
    final isConnected = ref.watch(connectionStatusProvider);
    final appTheme = ref.watch(themeProvider);
    
    // Verificar también el estado del servicio directamente como respaldo
    final serviceConnected = _ircService.isConnected;

    // Solo redirigir a LoginScreen si realmente no está conectado
    // (ni el provider ni el servicio indican conexión)
    if (!isConnected && !serviceConnected) {
      return const LoginScreen();
    }

    // Filtrar mensajes del canal actual (case-insensitive)
    final channelMessages = currentChannel != null
        ? messages.where((m) => m.channel.toLowerCase() == currentChannel.toLowerCase()).toList()
        : <IRCMessage>[];

    // Normalizar el nombre del canal para búsqueda (case-insensitive)
    print('🔍 [DEBUG] 🖼️  ChatScreen build: currentChannel=$currentChannel');
    print('🔍 [DEBUG] Available channels in provider: ${channels.keys.toList()}');
    
    final normalizedCurrentChannel = currentChannel?.toLowerCase();
    print('🔍 [DEBUG] Normalized current channel: $normalizedCurrentChannel');
    
    String? channelKey;
    if (normalizedCurrentChannel != null) {
      try {
        channelKey = channels.keys.firstWhere(
          (key) => key.toLowerCase() == normalizedCurrentChannel,
        );
        print('🔍 [DEBUG] Found channel key: $channelKey');
      } catch (e) {
        print('🔍 [DEBUG] ⚠️  Channel key not found: $e');
        channelKey = null;
      }
    }
    
    if (channelKey != null && channels.containsKey(channelKey)) {
      print('🔍 [DEBUG] Channel found in map: $channelKey');
      print('🔍 [DEBUG] Users in channel: ${channels[channelKey]!.users}');
      print('🔍 [DEBUG] Users count: ${channels[channelKey]!.users.length}');
    } else {
      print('🔍 [DEBUG] ⚠️  Channel not found or key is null');
      print('🔍 [DEBUG] channelKey: $channelKey');
      print('🔍 [DEBUG] channels.containsKey(channelKey): ${channelKey != null ? channels.containsKey(channelKey) : 'N/A'}');
    }
    
    final channelUsers = currentChannel != null && 
        channelKey != null && 
        channels.containsKey(channelKey)
        ? channels[channelKey]!.users
        : <String>[];

    print('🔍 [DEBUG] Final channelUsers count: ${channelUsers.length}');
    print('🔍 [DEBUG] Final channelUsers list: $channelUsers');

    // Verificar si el canal está completamente cargado
    // El canal está cargado si:
    // 1. Hay un canal actual
    // 2. El canal está en el mapa de canales (se ha unido exitosamente)
    // Nota: No verificamos si tiene usuarios porque algunos canales pueden estar vacíos
    final bool isChannelLoaded = currentChannel != null && 
        channelKey != null && 
        channels.containsKey(channelKey);

    // Si el canal no está cargado, mostrar pantalla de carga
    if (!isChannelLoaded && currentChannel != null && isConnected) {
      return _buildLoadingScreen(appTheme, currentChannel);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _disconnect();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(currentChannel ?? 'Cliente IRC'),
              if (nickname != null)
                Text(
                  'como $nickname',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
            ],
          ),
          backgroundColor: appTheme.primary,
          foregroundColor: appTheme.textPrimary,
          actions: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: isConnected ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    isConnected ? '● Conectado' : '● Desconectado',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            AnimatedServiceButton(
              appTheme: appTheme,
              tooltip: 'Centro de Atención a Usuarios',
              emoji: '💬',
              label: 'CAU',
              onPressed: () {
                _joinChannel('Ayuda');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Uniéndote al canal #Ayuda...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            AnimatedServiceButton(
              appTheme: appTheme,
              tooltip: 'Registro de Nick',
              emoji: '📝',
              label: 'Nick',
              onPressed: () {
                _showNickRegistrationDialog(context);
              },
            ),
            AnimatedServiceButton(
              appTheme: appTheme,
              tooltip: 'Registro de Canal',
              emoji: '📢',
              label: 'Canal',
              onPressed: () {
                _ircService.sendServiceMessage('ChanServ', 'HELP');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solicitando ayuda de registro de canal a ChanServ...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            AnimatedServiceButton(
              appTheme: appTheme,
              tooltip: 'Petición de IP Virtual',
              emoji: '🌐',
              label: 'IP Virtual',
              onPressed: () {
                _ircService.sendServiceMessage('HostServ', 'HELP');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Solicitando ayuda de IP virtual a HostServ...'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.palette),
              tooltip: 'Cambiar tema',
              onPressed: () => _showThemeSelector(context),
            ),
          ],
        ),
        body: Row(
          children: [
            // Channels sidebar
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.grey[900],
                child: Column(
                  children: [
                    // Header con gradiente
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            appTheme.primary,
                            appTheme.secondary,
                          ],
                        ),
                      ),
                      child: const Text(
                        'Canales y Mensajes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          // Separar canales y queries
                          final channelList = <String>[];
                          final queryList = <String>[];
                          
                          for (var channel in channels.keys) {
                            if (channel.startsWith('#')) {
                              // Filtrar canales que coincidan con el nickname del usuario
                              final currentNick = ref.read(currentNicknameProvider);
                              if (currentNick != null) {
                                final channelWithoutHash = channel.toLowerCase().replaceFirst('#', '');
                                final normalizedNick = currentNick.toLowerCase();
                                if (channelWithoutHash == normalizedNick || 
                                    channel.toLowerCase() == '#$normalizedNick') {
                                  continue; // Saltar este canal
                                }
                              }
                              channelList.add(channel);
                            } else {
                              queryList.add(channel);
                            }
                          }
                          
                          return ListView(
                            children: [
                              // Sección de Canales
                              if (channelList.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.tag,
                                        size: 16,
                                        color: appTheme.textPrimary.withOpacity(0.6),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'CANALES',
                                        style: TextStyle(
                                          color: appTheme.textPrimary.withOpacity(0.6),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...channelList.map((channel) => _buildChannelItem(
                                  context,
                                  channel,
                                  false,
                                  appTheme,
                                  currentChannel,
                                  ref,
                                )),
                                const SizedBox(height: 8),
                              ],
                              
                              // Sección de Mensajes Privados
                              if (queryList.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 16,
                                        color: appTheme.accent.withOpacity(0.8),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'MENSAJES PRIVADOS',
                                        style: TextStyle(
                                          color: appTheme.accent.withOpacity(0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ...queryList.map((channel) => _buildChannelItem(
                                  context,
                                  channel,
                                  true,
                                  appTheme,
                                  currentChannel,
                                  ref,
                                )),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _showJoinDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Unirse'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFA500), // Naranja
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Chat area
            Expanded(
              flex: 3,
              child: Column(
                children: [
                  // Topic bar con animación
                  if (currentChannel != null)
                    _buildTopicBar(currentChannel, channels, appTheme),
                  // Messages
                  Expanded(
                    child: currentChannel == null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Selecciona un canal para comenzar a chatear',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            children: [
                              // Fondo degradado cálido (multi-tono) para resaltar el ASCII
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF3B1F00), // tope cálido
                                        Color(0xFF2F1600), // transición oscura
                                        Color(0xFF3F1F00), // brillo medio
                                        Color(0xFF2A1200), // sombra
                                      ],
                                      stops: [0.0, 0.35, 0.65, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Resalte radial suave para dar profundidad
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: RadialGradient(
                                      center: const Alignment(0, -0.05),
                                      radius: 1.1,
                                      colors: [
                                        Colors.white.withOpacity(0.08),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 1.0],
                                    ),
                                  ),
                                ),
                              ),
                              // Logo ASCII con mayor opacidad
                              Positioned.fill(
                                child: Opacity(
                                  opacity: 0.38, // subir opacidad para que se lean mejor las letras
                                  child: const _AsciiBackground(),
                                ),
                              ),
                              // Capa de oscurecido muy ligera para conservar contraste sin tapar el logo
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.black.withOpacity(0.06),
                                        Colors.black.withOpacity(0.12),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                              // Lista de mensajes
                              Positioned.fill(
                                child: ListView.builder(
                            reverse: true,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: channelMessages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  channelMessages[channelMessages.length - 1 - index];
                              return _buildMessageTile(message);
                            },
                                ),
                              ),
                            ],
                          ),
                  ),
                  const Divider(height: 1),
                  // Input area
                  if (currentChannel != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          PopupMenuButton<String>(
                            icon: Icon(Icons.image, color: appTheme.primary),
                            tooltip: 'Adjuntar imagen',
                            onSelected: (value) {
                              if (value == 'pick') {
                                _pickAndSendImage();
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'pick',
                                child: Row(
                                  children: [
                                    Icon(Icons.folder, size: 20),
                                    SizedBox(width: 8),
                                    Text('Seleccionar imagen o video'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Shortcuts(
                              shortcuts: {
                                const SingleActivator(LogicalKeyboardKey.keyV, meta: true): 
                                  const PasteImageIntent(),
                              },
                              child: Actions(
                                actions: {
                                  PasteImageIntent: CallbackAction<PasteImageIntent>(
                                    onInvoke: (intent) {
                                      _pasteImageFromClipboard();
                                      return null;
                                    },
                                  ),
                                },
                                child: Focus(
                                  child: TextField(
                                    controller: _messageController,
                                    decoration: InputDecoration(
                                      hintText: 'Mensaje... (Pega imágenes con Cmd+V)',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      fillColor: appTheme.surface,
                                      filled: true,
                                    ),
                                    onSubmitted: (_) => _sendMessage(),
                                    minLines: 1,
                                    maxLines: 3,
                                    keyboardType: TextInputType.multiline,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FloatingActionButton(
                            onPressed: _sendMessage,
                            mini: true,
                            backgroundColor: appTheme.primary,
                            child: const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Users sidebar - Solo mostrar para canales, no para queries (mensajes privados)
            if (currentChannel != null && currentChannel!.startsWith('#'))
              Expanded(
                flex: 1,
                child: Container(
                  color: Colors.grey[900],
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              appTheme.primary,
                              appTheme.secondary,
                            ],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Usuarios',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              '${channelUsers.length} usuarios',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (channelUsers.isEmpty)
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Aún no hay usuarios',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            itemCount: channelUsers.length,
                            itemBuilder: (context, index) {
                              final user = channelUsers[index];
                              // Obtener el canal para verificar si el usuario es un robot
                              IRCChannel? currentChannelData;
                              if (channelKey != null && channels.containsKey(channelKey)) {
                                currentChannelData = channels[channelKey];
                              }
                              // Verificar si el usuario es un robot
                              final isRobot = currentChannelData?.isRobot(user) ?? false;
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  isRobot ? Icons.smart_toy : Icons.person,
                                  color: isRobot ? const Color(0xFFFFD700) : Colors.white70,
                                  size: 16,
                                ),
                                title: Text(
                                  user,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: isRobot ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _disconnect,
          backgroundColor: Colors.red,
          child: const Icon(Icons.logout),
        ),
        bottomNavigationBar: const RadioControls(),
      ),
    );
  }

  Widget _buildMessageTile(IRCMessage message) {
    final timeFormat = DateFormat('HH:mm');
    final currentNick = ref.read(currentNicknameProvider);
    final isOwnMessage = message.nick == currentNick;
    
    if (message.isSystem) {
      // Detectar si es JOIN o PART
      final isJoin = message.message.contains('se unió');
      final isPart = message.message.contains('dejó') || message.message.contains('salió');
      
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isJoin
                    ? [
                        Colors.green.withOpacity(0.2),
                        Colors.greenAccent.withOpacity(0.15),
                      ]
                    : [
                        Colors.orange.withOpacity(0.2),
                        Colors.redAccent.withOpacity(0.15),
                      ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isJoin
                    ? Colors.green.withOpacity(0.4)
                    : Colors.orange.withOpacity(0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isJoin ? Colors.green : Colors.orange)
                      .withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isJoin ? Colors.green : Colors.orange)
                        .withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isJoin ? Icons.person_add : Icons.person_remove,
                    size: 16,
                    color: isJoin ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  message.nick,
            style: TextStyle(
                    color: isJoin ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  message.message,
                  style: TextStyle(
                    color: isJoin
                        ? Colors.green[600]
                        : Colors.orange[600],
              fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Generar color basado en el hash del nickname para consistencia
    final nickHash = message.nick.hashCode;
    final userColor = _getUserColor(nickHash);
    
    // Obtener inicial del usuario para el avatar
    final userInitial = message.nick.isNotEmpty 
        ? message.nick[0].toUpperCase() 
        : '?';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage) ...[
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: userColor.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: userColor.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  userInitial,
                  style: TextStyle(
                    color: userColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Burbuja de mensaje
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOwnMessage 
                    ? const Color(0xFFFFA500) // Naranja para mensajes propios
                    : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isOwnMessage ? 18 : 4),
                  bottomRight: Radius.circular(isOwnMessage ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  // Nickname y hora
          Row(
                    mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.nick,
                        style: TextStyle(
                  fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isOwnMessage 
                              ? Colors.white 
                              : userColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeFormat.format(message.timestamp),
                style: TextStyle(
                          fontSize: 11,
                          color: isOwnMessage 
                              ? Colors.white70 
                              : Colors.grey[600],
                          fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
                  const SizedBox(height: 6),
                  // Contenido del mensaje con soporte para imágenes
                  _buildMessageContent(message.message, isOwnMessage),
                ],
              ),
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 8),
            // Avatar para mensajes propios
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFFA500).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFA500).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  currentNick != null && currentNick.isNotEmpty
                      ? currentNick[0].toUpperCase()
                      : 'Y',
                  style: const TextStyle(
                    color: Color(0xFFFF8C00), // Naranja oscuro
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent(String messageText, bool isOwnMessage) {
    // Detectar si el mensaje contiene una imagen (data URI)
    if (messageText.contains('data:image/')) {
      final parts = messageText.split('data:image/');
      if (parts.length > 1) {
        final dataUri = 'data:image/${parts[1].split(' ')[0]}';
        final remainingText = parts.length > 1 && parts[1].contains(' ')
            ? parts[1].substring(parts[1].indexOf(' ') + 1)
            : '';
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (messageText.startsWith('[Imagen]'))
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                constraints: const BoxConstraints(
                  maxWidth: 300,
                  maxHeight: 300,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOwnMessage 
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(dataUri.split(',')[1]),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        child: const Icon(Icons.broken_image, size: 48),
                      );
                    },
                  ),
                ),
              ),
            if (remainingText.isNotEmpty)
          Text(
                remainingText,
                style: TextStyle(
                  color: isOwnMessage 
                      ? Colors.white 
                      : Colors.black87,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
          ],
        );
      }
    }
    
    // Detectar URLs de videos (incluyendo Cloudinary)
    final videoUrlRegex = RegExp(
      r'https?://(?:[^\s]+\.(?:mp4|webm|mov)|res\.cloudinary\.com/[^\s]*video[^\s]*)',
      caseSensitive: false,
    );
    final videoMatches = videoUrlRegex.allMatches(messageText);
    
    if (videoMatches.isNotEmpty) {
      final parts = <Widget>[];
      int lastEnd = 0;
      
      for (var match in videoMatches) {
        // Texto antes de la URL
        if (match.start > lastEnd) {
          parts.add(Text(
            messageText.substring(lastEnd, match.start),
            style: TextStyle(
              color: isOwnMessage 
                  ? Colors.white 
                  : Colors.black87,
              fontSize: 14,
              height: 1.4,
            ),
          ));
        }
        
        // Widget del video
        parts.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 300,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOwnMessage 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Placeholder mientras carga
                  Container(
                    width: double.infinity,
                    height: 200,
                    color: Colors.black87,
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                  // Botón para abrir el video
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          final url = match.group(0)!;
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white70,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Mostrar la URL del video como texto
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '🎥 Video - Toca para reproducir',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        
        lastEnd = match.end;
      }
      
      // Texto después de la última URL
      if (lastEnd < messageText.length) {
        parts.add(Text(
          messageText.substring(lastEnd),
          style: TextStyle(
            color: isOwnMessage 
                ? Colors.white 
                : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ));
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts,
      );
    }
    
    // Detectar URLs de imágenes (incluyendo Cloudinary)
    final imageUrlRegex = RegExp(
      r'https?://(?:[^\s]+\.(?:jpg|jpeg|png|gif|webp)|res\.cloudinary\.com/[^\s]*(?<!video)[^\s]*)',
      caseSensitive: false,
    );
    final matches = imageUrlRegex.allMatches(messageText);
    
    if (matches.isNotEmpty) {
      final parts = <Widget>[];
      int lastEnd = 0;
      
      for (var match in matches) {
        // Texto antes de la URL
        if (match.start > lastEnd) {
          parts.add(Text(
            messageText.substring(lastEnd, match.start),
            style: TextStyle(
              color: isOwnMessage 
                  ? Colors.white 
                  : Colors.black87,
              fontSize: 14,
              height: 1.4,
            ),
          ));
        }
        
        // Imagen
        parts.add(
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            constraints: const BoxConstraints(
              maxWidth: 300,
              maxHeight: 300,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOwnMessage 
                    ? Colors.white.withOpacity(0.3)
                    : Colors.grey.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                match.group(0)!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: const CircularProgressIndicator(),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: const Icon(Icons.broken_image, size: 48),
                  );
                },
              ),
            ),
          ),
        );
        
        lastEnd = match.end;
      }
      
      // Texto después de la última URL
      if (lastEnd < messageText.length) {
        parts.add(Text(
          messageText.substring(lastEnd),
          style: TextStyle(
            color: isOwnMessage 
                ? Colors.white 
                : Colors.black87,
            fontSize: 14,
            height: 1.4,
          ),
        ));
      }
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts,
      );
    }
    
    // Mensaje normal sin imágenes
    return Text(
      messageText,
      style: TextStyle(
        color: isOwnMessage 
            ? Colors.white 
            : Colors.black87,
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

  // Generar color consistente basado en el hash del nickname
  Color _getUserColor(int hash) {
    final colors = [
      const Color(0xFFFFA500), // Naranja
      const Color(0xFFFFD700), // Amarillo dorado
      const Color(0xFFFF8C00), // Naranja oscuro
      const Color(0xFFFFE4B5), // Amarillo claro
      Colors.orange,
      Colors.amber,
      const Color(0xFFFFB347), // Naranja claro
      const Color(0xFFFFCC00), // Amarillo
      Colors.deepOrange,
      const Color(0xFFFFE135), // Amarillo brillante
    ];
    return colors[hash.abs() % colors.length];
  }

  // Widget para mostrar el topic con animación moderna
  Widget _buildTopicBar(String? channel, Map<String, IRCChannel> channels, AppTheme appTheme) {
    if (channel == null) return const SizedBox.shrink();
    
    // Buscar el canal de forma case-insensitive
    IRCChannel? channelData;
    for (var entry in channels.entries) {
      if (entry.key.toLowerCase() == channel.toLowerCase()) {
        channelData = entry.value;
        break;
      }
    }
    
    final topic = channelData?.topic;
    
    if (topic == null || topic.isEmpty) {
      return Container(
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              appTheme.primary.withOpacity(0.2),
              appTheme.secondary.withOpacity(0.2),
            ],
          ),
        ),
        child: Center(
          child: Text(
            'Sin tema establecido',
            style: TextStyle(
              color: appTheme.textSecondary,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            appTheme.primary,
            appTheme.secondary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.primary.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRect(
        clipBehavior: Clip.hardEdge,
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxHeight: 40,
          child: AnimatedTopicText(topic: topic),
        ),
      ),
    );
  }

  Widget _buildChannelItem(
    BuildContext context,
    String channel,
    bool isQuery,
    AppTheme appTheme,
    String? currentChannel,
    WidgetRef ref,
  ) {
    final normalizedCurrent = currentChannel?.toLowerCase();
    final normalizedChannel = channel.toLowerCase();
    final isSelected = normalizedChannel == normalizedCurrent;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? (isQuery 
                ? appTheme.accent.withOpacity(0.2)
                : appTheme.accent.withOpacity(0.3))
            : (isQuery
                ? appTheme.accent.withOpacity(0.05)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(10),
        border: isSelected
            ? Border.all(
                color: isQuery ? appTheme.accent : appTheme.accent,
                width: 2,
              )
            : (isQuery
                ? Border.all(
                    color: appTheme.accent.withOpacity(0.3),
                    width: 1,
                  )
                : null),
      ),
      child: ListTile(
        selected: isSelected,
        selectedTileColor: Colors.transparent,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isQuery
                ? appTheme.accent.withOpacity(isSelected ? 0.3 : 0.15)
                : appTheme.primary.withOpacity(isSelected ? 0.3 : 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isQuery ? Icons.person : Icons.tag,
            color: isSelected
                ? (isQuery ? appTheme.accent : appTheme.accent)
                : (isQuery 
                    ? appTheme.accent.withOpacity(0.8)
                    : appTheme.textPrimary.withOpacity(0.7)),
            size: 18,
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                isQuery ? channel : channel,
                style: TextStyle(
                  color: isSelected
                      ? (isQuery ? appTheme.accent : appTheme.accent)
                      : appTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isQuery)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: appTheme.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'PRIV',
                  style: TextStyle(
                    color: appTheme.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        onTap: () {
          ref.read(currentChannelProvider.notifier).state = channel;
        },
        trailing: IconButton(
          icon: Icon(
            Icons.close,
            color: appTheme.textPrimary.withOpacity(0.5),
            size: 16,
          ),
          onPressed: () {
            // Si es un query (no empieza con #), solo removerlo de la lista
            if (isQuery) {
              _ircService.allChannels.remove(channel);
              ref.read(channelsProvider.notifier).updateChannels();
              final normalizedCurrentChannel = currentChannel?.toLowerCase();
              if (normalizedCurrentChannel == normalizedChannel) {
                ref.read(currentChannelProvider.notifier).state = null;
              }
            } else {
              // Si es un canal, hacer PART
              _ircService.partChannel(channel);
              ref.read(channelsProvider.notifier).updateChannels();
              final normalizedCurrentChannel = currentChannel?.toLowerCase();
              if (normalizedCurrentChannel == normalizedChannel) {
                ref.read(currentChannelProvider.notifier).state = null;
              }
            }
          },
        ),
      ),
    );
  }

  void _showJoinDialog(BuildContext context) {
    final controller = TextEditingController();
    final appTheme = ref.read(themeProvider);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirse a Canal'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '#channelname',
            prefixIcon: Icon(Icons.tag),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              _joinChannel(controller.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: appTheme.primary,
              foregroundColor: appTheme.textPrimary,
            ),
            child: const Text('Unirse'),
          ),
        ],
      ),
    );
  }

  void _showNickRegistrationDialog(BuildContext context) {
    final appTheme = ref.read(themeProvider);
    final nickController = TextEditingController();
    final passwordController = TextEditingController();
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool _obscurePassword = true;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  appTheme.surface,
                  appTheme.surface.withOpacity(0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: appTheme.primary.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con gradiente
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          appTheme.primary,
                          appTheme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '📝',
                            style: TextStyle(fontSize: 24),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registro de Nick',
                                style: TextStyle(
                                  color: appTheme.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Registra tu nick en el servidor IRC',
                                style: TextStyle(
                                  color: appTheme.textPrimary.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contenido del formulario
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Campo Nick
                        TextFormField(
                          controller: nickController,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Nick a registrar',
                            hintText: 'Ej: MiNick',
                            prefixIcon: Icon(Icons.person, color: appTheme.primary),
                            filled: true,
                            fillColor: appTheme.surface.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary, width: 2),
                            ),
                            labelStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.7)),
                            hintStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.5)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa un nick';
                            }
                            if (value.contains(' ')) {
                              return 'El nick no puede contener espacios';
                            }
                            if (value.length < 3) {
                              return 'El nick debe tener al menos 3 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Campo Password
                        TextFormField(
                          controller: passwordController,
                          obscureText: _obscurePassword,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            hintText: 'Ingresa una contraseña segura',
                            prefixIcon: Icon(Icons.lock, color: appTheme.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                color: appTheme.textPrimary.withOpacity(0.7),
                              ),
                              onPressed: () {
                                setDialogState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: appTheme.surface.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary, width: 2),
                            ),
                            labelStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.7)),
                            hintStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.5)),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Por favor ingresa una contraseña';
                            }
                            if (value.length < 6) {
                              return 'La contraseña debe tener al menos 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        // Campo Email
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'tu@email.com',
                            prefixIcon: Icon(Icons.email, color: appTheme.primary),
                            filled: true,
                            fillColor: appTheme.surface.withOpacity(0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: appTheme.primary, width: 2),
                            ),
                            labelStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.7)),
                            hintStyle: TextStyle(color: appTheme.textPrimary.withOpacity(0.5)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Por favor ingresa un email';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                              return 'Por favor ingresa un email válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        // Botones
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: appTheme.textPrimary.withOpacity(0.7),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    appTheme.primary,
                                    appTheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: appTheme.primary.withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () {
                                  if (formKey.currentState!.validate()) {
                                    // Enviar comando de registro a NickServ
                                    final nick = nickController.text.trim();
                                    final password = passwordController.text;
                                    final email = emailController.text.trim();
                                    
                                    // Comando típico de registro: REGISTER password email
                                    _ircService.sendServiceMessage(
                                      'NickServ',
                                      'REGISTER $password $email',
                                    );
                                    
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Registrando nick "$nick" en NickServ...'),
                                        backgroundColor: appTheme.primary,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Aceptar',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    final currentTheme = ref.read(themeProvider);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Tema'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppTheme.themes.length,
            itemBuilder: (context, index) {
              final theme = AppTheme.themes[index];
              final isSelected = theme.name == currentTheme.name;
              
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.primary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.accent,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  theme.name,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme(theme);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// Fondo tipo ASCII con letras en gradiente cálido inspirado en la imagen de referencia
class _AsciiBackground extends StatelessWidget {
  const _AsciiBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AsciiBackgroundPainter(),
    );
  }
}

// Widget de spinner moderno animado
class _ModernLoadingSpinner extends ConsumerStatefulWidget {
  const _ModernLoadingSpinner();

  @override
  ConsumerState<_ModernLoadingSpinner> createState() => _ModernLoadingSpinnerState();
}

class _ModernLoadingSpinnerState extends ConsumerState<_ModernLoadingSpinner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159, // 360 grados en radianes
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 1),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    appTheme.primary,
                    appTheme.secondary,
                    appTheme.accent,
                    appTheme.primary,
                  ],
                  stops: const [0.0, 0.33, 0.66, 1.0],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appTheme.background,
                ),
                child: Center(
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 50,
                    color: appTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget de barra de progreso animada
class _LoadingProgressBar extends ConsumerStatefulWidget {
  const _LoadingProgressBar();

  @override
  ConsumerState<_LoadingProgressBar> createState() => _LoadingProgressBarState();
}

class _LoadingProgressBarState extends ConsumerState<_LoadingProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: appTheme.surface,
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: _controller.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: LinearGradient(
                      colors: [
                        appTheme.primary,
                        appTheme.secondary,
                        appTheme.accent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AsciiBackgroundPainter extends CustomPainter {
  static const String _asciiLogo = '''
   _____ _       _           _  _____ _           _   
  / ____| |     | |         | |/ ____| |         | |  
 | |  __| | ___ | |__   __ _| | |    | |__   __ _| |_ 
 | | |_ | |/ _ \\| '_ \\ / _` | | |    | '_ \\ / _` | __|
 | |__| | | (_) | |_) | (_| | | |____| | | | (_| | |_ 
  \\_____|_|\\___/|_.__/ \\__,_|_|\\_____|_| |_|\\__,_|\\__|

          IRC Network · Desde 1999-2025                
  ''';

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final baseRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = const LinearGradient(
      colors: [
        Color(0xFFFFD700), // Dorado brillante
        Color(0xFFFFF44F), // Amarillo intenso
        Color(0xFFFFD700), // Dorado
        Color(0xFF4169E1), // Azul Royal
        Color(0xFFE31E24), // Rojo GlobalChat
        Color(0xFFFFD700), // Dorado
        Color(0xFFFFF44F), // Amarillo brillante
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(baseRect);

    final logoPaint = Paint()..shader = gradient;
    final logoStyle = TextStyle(
      fontFamily: 'Courier New', // monoespaciada muy estable
      fontFamilyFallback: const ['Menlo', 'SFMono-Regular', 'monospace'],
      fontSize: size.width * 0.022, // aún más pequeña para evitar cualquier wrap
      fontWeight: FontWeight.w700,
      height: 1.0, // filas alineadas
      foreground: logoPaint,
      letterSpacing: 0, // sin espaciado extra
    );

    final logoPainter = TextPainter(
      text: TextSpan(text: _asciiLogo, style: logoStyle),
      textAlign: TextAlign.center,
      textDirection: ui.TextDirection.ltr,
      textWidthBasis: TextWidthBasis.longestLine,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: true,
        applyHeightToLastDescent: true,
      ),
    )..layout(maxWidth: size.width * 0.85); // margen mayor para evitar descolocación

    final logoOffset = Offset(
      (size.width - logoPainter.width) / 2,
      (size.height - logoPainter.height) / 2,
    );

    // Opacidad ligera y sensación de texto de fondo
    canvas.saveLayer(baseRect, Paint()..color = Colors.white.withOpacity(0.32));
    logoPainter.paint(canvas, logoOffset);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
