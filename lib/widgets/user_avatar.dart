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

  @override
  void initState() {
    super.initState();
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
  }

  @override
  Widget build(BuildContext context) {
    // Observar cambios en el provider de refresco de avatares
    final refreshTimestamp = ref.watch(avatarRefreshProvider)[widget.nick.toLowerCase()];
    
    // Si el timestamp cambió, recargar el avatar
    if (refreshTimestamp != null && refreshTimestamp != _lastRefreshTimestamp) {
      _lastRefreshTimestamp = refreshTimestamp;
      _loadAvatar();
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
    
    // print('🔍 [AVATAR WIDGET] Loading avatar for: "$cleanNick" (original: "${widget.nick}")');
    
    // Obtener la URL correcta del avatar (intenta ambas variantes)
    final url = await AvatarService.getCorrectAvatarUrl(cleanNick);
    
    if (mounted) {
      setState(() {
        _avatarUrl = url;
        _avatarLoaded = true;
        // print('🔍 [AVATAR WIDGET] Avatar URL set for "$cleanNick": ${url ?? "not found"}');
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
    }
    
    // Detectar si el fallbackIcon es una URL (emoticono de JoyPixels)
    final isFallbackUrl = widget.fallbackIcon != null && 
        (widget.fallbackIcon!.startsWith('http://') || 
         widget.fallbackIcon!.startsWith('https://'));
    
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
          child: _avatarUrl != null && _avatarLoaded
              ? Image.network(
                  _avatarUrl!,
                  key: ValueKey('${widget.nick}_${_avatarUrl}_${_lastRefreshTimestamp ?? 0}'), // Clave única para que AnimatedSwitcher detecte el cambio
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
                      return child;
                    }
                    // Mientras carga, mostrar el fallback con opacidad reducida
                    return Opacity(
                      opacity: 0.5,
                      child: _buildFallback(fallback, isFallbackUrl),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Si falla la carga, mostrar fallback
                    // En web, los errores de CORS pueden causar que las imágenes no se carguen
                    return _buildFallback(fallback, isFallbackUrl);
                  },
                )
              : _buildFallback(fallback, isFallbackUrl, key: ValueKey('${widget.nick}_fallback')),
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
