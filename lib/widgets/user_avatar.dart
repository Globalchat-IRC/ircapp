import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../services/avatar_service.dart';
import '../providers/irc_provider.dart';

class UserAvatar extends ConsumerStatefulWidget {
  final String nick;
  final double size;
  final String? fallbackIcon; // Emoji o inicial
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final String? username; // Para detectar robots
  final String? host; // Para detectar robots

  const UserAvatar({
    Key? key,
    required this.nick,
    this.size = 42,
    this.fallbackIcon,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.boxShadow,
    this.username,
    this.host,
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
    
    print('🔍 [AVATAR WIDGET] Loading avatar for: "$cleanNick" (original: "${widget.nick}")');
    
    // Obtener la URL correcta del avatar (intenta ambas variantes)
    final url = await AvatarService.getCorrectAvatarUrl(cleanNick);
    
    if (mounted) {
      setState(() {
        _avatarUrl = url;
        _avatarLoaded = true;
        print('🔍 [AVATAR WIDGET] Avatar URL set for "$cleanNick": ${url ?? "not found"}');
      });
    }
  }
  

  Widget _buildAvatarWidget() {
    // Detectar si es un robot (contiene "Robot" en el nick, username o host)
    final isRobot = _isRobot(widget.nick);
    
    final fallback = widget.fallbackIcon ?? 
        (isRobot ? '🤖' : (widget.nick.isNotEmpty ? widget.nick[0].toUpperCase() : '?'));
    
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
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      print('🔍 [AVATAR WIDGET] Image loaded successfully for "${widget.nick}" from $_avatarUrl');
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
                    print('🔍 [AVATAR WIDGET] Error loading image for "${widget.nick}" from $_avatarUrl: $error');
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
        fit: BoxFit.cover,
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

  // Detectar si el usuario es un robot
  bool _isRobot(String nick) {
    final lowerNick = nick.toLowerCase();
    // Verificar si contiene "robot" en el nick
    if (lowerNick.contains('robot')) {
      return true;
    }
    
    // Verificar en username y host si están disponibles
    if (widget.username != null && widget.username!.toLowerCase().contains('robot')) {
      return true;
    }
    
    if (widget.host != null && widget.host!.toLowerCase().contains('robot')) {
      return true;
    }
    
    return false;
  }
}
