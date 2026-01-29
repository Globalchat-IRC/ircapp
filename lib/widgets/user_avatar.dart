import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/painting.dart' show WebHtmlElementStrategy;
import '../services/avatar_service.dart';
import '../providers/irc_provider.dart';
import '../utils/platform_utils.dart';

class UserAvatar extends ConsumerStatefulWidget {
  final String nick;
  final double size;
  final String? fallbackIcon; // Emoji o inicial
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool isRobot; // Si es true, no intenta cargar avatar de la red, usa directamente el fallback

  const UserAvatar({
    Key? key,
    required this.nick,
    this.size = 42,
    this.fallbackIcon,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.boxShadow,
    this.isRobot = false,
  }) : super(key: key);

  @override
  ConsumerState<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<UserAvatar> {
  String? _avatarUrl;
  bool _avatarLoaded = false;
  int? _lastRefreshTimestamp;
  bool _lastIsRobot = false;
  bool _triedDefaultAvatar = false;

  @override
  void initState() {
    super.initState();
    _lastIsRobot = widget.isRobot;
    print('🔵 [UserAvatar] initState para "${widget.nick}", isRobot: ${widget.isRobot}');
    _loadAvatar();
    // Registrar el avatar para refresco automático
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(avatarRefreshProvider.notifier).refreshAvatar(widget.nick);
      }
    });
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambió el nick, recargar avatar
    if (oldWidget.nick != widget.nick) {
      _avatarLoaded = false;
      _avatarUrl = null;
      _lastRefreshTimestamp = null;
      _loadAvatar();
      // Registrar el nuevo nick para refresco fuera del ciclo de build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref
              .read(avatarRefreshProvider.notifier)
              .refreshAvatar(widget.nick);
        }
      });
    }
    // Si cambió isRobot, recargar avatar (importante: puede cambiar la detección)
    if (oldWidget.isRobot != widget.isRobot) {
      print('🔄 [UserAvatar] isRobot cambió para "${widget.nick}": ${oldWidget.isRobot} → ${widget.isRobot}');
      _lastIsRobot = widget.isRobot; // Actualizar inmediatamente
      _avatarLoaded = false;
      _avatarUrl = null;
      // No resetear _lastRefreshTimestamp para mantener el timestamp actual
      // Forzar refresh del avatar cuando cambia isRobot
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAvatar();
          ref
              .read(avatarRefreshProvider.notifier)
              .refreshAvatar(widget.nick);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Observar cambios en el provider de refresco de avatares
    final refreshTimestamp = ref.watch(avatarRefreshProvider)[widget.nick.toLowerCase()];
    
    // Si el timestamp cambió, recargar el avatar
    if (refreshTimestamp != null && refreshTimestamp != _lastRefreshTimestamp) {
      _lastRefreshTimestamp = refreshTimestamp;
      // Usar post-frame callback para evitar llamar setState durante build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAvatar();
        }
      });
    }
    
    // Si cambió isRobot, recargar el avatar inmediatamente
    if (_lastIsRobot != widget.isRobot) {
      _lastIsRobot = widget.isRobot;
      // Limpiar inmediatamente para forzar el cambio visual
      _avatarLoaded = false;
      _avatarUrl = null;
      // Usar post-frame callback para evitar llamar setState durante build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadAvatar();
        }
      });
    }
    
    return _buildAvatarWidget();
  }

  Future<void> _loadAvatar() async {
    if (widget.nick.isEmpty) {
      setState(() {
        _avatarLoaded = true;
      });
      return;
    }
    
    // Limpiar el nick para asegurar que no tenga espacios extra
    final cleanNick = widget.nick.trim();
    if (cleanNick.isEmpty) {
      setState(() {
        _avatarLoaded = true;
      });
      return;
    }
    
    // Si es un robot, no intentar cargar avatar de la red, usar directamente el fallback
    if (widget.isRobot) {
      print('🤖 [UserAvatar] Robot detectado para "${widget.nick}", usando fallback: "${widget.fallbackIcon}"');
      if (mounted) {
        setState(() {
          _avatarUrl = null; // Forzar uso del fallback
          _avatarLoaded = true;
        });
      }
      return;
    }
    
    // Usuario normal: intentar cargar avatar personalizado
    print('👤 [UserAvatar] Usuario normal "${widget.nick}" (isRobot: ${widget.isRobot}), cargando avatar personalizado...');
    
    // Obtener la URL correcta del avatar (intenta ambas variantes)
    // Agregar timestamp para forzar recarga cuando cambia isRobot
    final url = await AvatarService.getCorrectAvatarUrl(cleanNick);
    
    print('👤 [UserAvatar] URL del avatar para "${widget.nick}": ${url ?? "null"}');
    
    if (mounted) {
      setState(() {
        _avatarUrl = url;
        _avatarLoaded = true;
        _triedDefaultAvatar = false; // reset al recargar
        print('👤 [UserAvatar] Avatar cargado para "${widget.nick}": _avatarUrl=${_avatarUrl != null ? "set" : "null"}, _avatarLoaded=$_avatarLoaded');
      });
    }
  }
  

  Widget _buildAvatarWidget() {
    // Verificar si hay un icono personalizado para este usuario
    final userIcons = ref.read(userIconsProvider);
    final customIcon = userIcons[widget.nick.toLowerCase()];
    
    final fallback = widget.fallbackIcon ?? 
        customIcon ??
        (widget.nick.isNotEmpty ? widget.nick[0].toUpperCase() : '?');
    
    // Debug para robots
    if (widget.isRobot) {
      print('🤖 [UserAvatar] Construyendo avatar para robot "${widget.nick}", fallback: "$fallback", _avatarUrl: $_avatarUrl, _avatarLoaded: $_avatarLoaded');
    } else {
      // Debug para usuarios normales
      print('👤 [UserAvatar] Construyendo avatar para usuario normal "${widget.nick}", fallback: "$fallback", _avatarUrl: $_avatarUrl, _avatarLoaded: $_avatarLoaded, isRobot: ${widget.isRobot}');
    }
    
    // Detectar si el fallbackIcon es una URL (emoticono de JoyPixels)
    final isFallbackUrl = widget.fallbackIcon != null && 
        (widget.fallbackIcon!.startsWith('http://') || 
         widget.fallbackIcon!.startsWith('https://'));
    
    // Para usuarios normales, siempre intentar cargar el avatar si tenemos una URL
    // Incluso si _avatarLoaded es false, intentar cargar para que el errorBuilder maneje el fallback
    final shouldTryLoadAvatar = !widget.isRobot && _avatarUrl != null;
    
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: widget.gradient,
        color: widget.gradient == null ? widget.backgroundColor : null,
        shape: BoxShape.circle,
        border: widget.border,
        boxShadow: widget.boxShadow,
      ),
      child: ClipOval(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: shouldTryLoadAvatar
              ? Image.network(
                  _avatarUrl!,
                  key: ValueKey('${widget.nick}_avatar_${widget.isRobot}_${_lastRefreshTimestamp ?? 0}'), // Incluir isRobot en la clave para forzar recarga cuando cambia
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.contain,
                  // En web, usar WebHtmlElementStrategy.prefer para evitar problemas de CORS
                  // Esto intenta usar elementos HTML <img> que no tienen las mismas restricciones CORS
                  // Nota: Los errores de CORS en la consola son esperados y no afectan la funcionalidad
                  // El navegador intentará cargar la imagen usando <img> si el fetch falla
                  webHtmlElementStrategy: PlatformUtils.isWeb 
                      ? WebHtmlElementStrategy.prefer 
                      : WebHtmlElementStrategy.never,
                  // Suprimir errores de CORS en la consola no es posible desde Flutter
                  // pero el fallback visual funcionará correctamente
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      print('✅ [UserAvatar] Avatar cargado exitosamente para "${widget.nick}"');
                      return child;
                    }
                    // Mientras carga, mostrar el fallback con opacidad reducida
                    print('⏳ [UserAvatar] Cargando avatar para "${widget.nick}": ${loadingProgress.cumulativeBytesLoaded}/${loadingProgress.expectedTotalBytes ?? 0} bytes');
                    return Opacity(
                      opacity: 0.5,
                      child: _buildFallback(fallback, isFallbackUrl, key: ValueKey('${widget.nick}_loading_${widget.isRobot}')),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Si falla la carga del avatar personalizado, intentar una vez
                    // el avatar generado por defecto del panel. Si también falla,
                    // mostrar el fallback (emoji / inicial).
                    print('⚠️ [UserAvatar] Error cargando avatar para "${widget.nick}": $error');
                    print('⚠️ [UserAvatar] Stack trace: $stackTrace');

                    if (!_triedDefaultAvatar) {
                      _triedDefaultAvatar = true;
                      final cleanNick = widget.nick.trim();
                      final defaultUrl = AvatarService.getDefaultAvatarUrl(cleanNick);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _avatarUrl = defaultUrl;
                          });
                        }
                      });
                    }

                    return _buildFallback(
                      fallback,
                      isFallbackUrl,
                      key: ValueKey('${widget.nick}_error_${widget.isRobot}_${_triedDefaultAvatar ? "default" : "custom"}'),
                    );
                  },
                )
              : _buildFallback(fallback, isFallbackUrl, key: ValueKey('${widget.nick}_fallback_${widget.isRobot}_${_lastRefreshTimestamp ?? 0}')), // Incluir isRobot y timestamp en la clave del fallback
        ),
      ),
    );
  }
  
  Widget _buildFallback(String fallback, bool isUrl, {Key? key}) {
    Widget fallbackWidget;
    if (isUrl && widget.fallbackIcon != null) {
      // Si es una URL, mostrar como imagen
      fallbackWidget = Image.network(
        widget.fallbackIcon!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Si falla, mostrar texto
          return Center(
            child: Text(
              widget.nick.isNotEmpty ? widget.nick[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: widget.size * 0.4,
              ),
            ),
          );
        },
      );
    } else {
      // Si es emoji Unicode o inicial, mostrar como texto
      fallbackWidget = Center(
        child: Text(
          fallback,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: widget.size * 0.4,
          ),
        ),
      );
    }
    return key != null ? KeyedSubtree(key: key, child: fallbackWidget) : fallbackWidget;
  }
}
