import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/painting.dart' show WebHtmlElementStrategy;
import '../services/avatar_service.dart';
import '../providers/irc_provider.dart';
import '../utils/platform_utils.dart';
import '../models/whois_info.dart';

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
  String? _staticAvatarUrl;
  String? _gifAvatarUrl;
  bool _avatarLoaded = false;
  int? _lastRefreshTimestamp;
  bool _lastIsRobot = false;
  bool _triedDefaultAvatar = false;
  bool _gifPreferred = false;

  @override
  void initState() {
    super.initState();
    _lastIsRobot = widget.isRobot;
    print('🔵 [UserAvatar] initState para "${widget.nick}", isRobot: ${widget.isRobot}');
    _loadAvatar();
    // Asegurar carga tras el primer frame (por si el setState no se aplica a tiempo en web)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.isRobot && _avatarUrl == null && widget.nick.trim().isNotEmpty) {
        _loadAvatar();
      }
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
    // Observar solo el timestamp de este nick (evita reconstruir todos los avatares del canal)
    final refreshTimestamp = ref.watch(
      avatarRefreshProvider.select((m) => m[widget.nick.toLowerCase()]),
    );
    
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
    
    // Usuario normal: intentar primero avatar GIF animado y luego PNG estático
    print('👤 [UserAvatar] Usuario normal "${widget.nick}" (isRobot: ${widget.isRobot}), cargando avatar (GIF + PNG)...');

    final staticUrl = await AvatarService.getCorrectAvatarUrl(cleanNick);
    final gifUrl = AvatarService.getAvatarGifUrl(cleanNick);
    
    print('👤 [UserAvatar] URL estática para "${widget.nick}": ${staticUrl ?? "null"}');
    print('👤 [UserAvatar] URL GIF para "${widget.nick}": $gifUrl');
    
    if (mounted) {
      setState(() {
        _staticAvatarUrl = staticUrl;
        _gifAvatarUrl = gifUrl;
        _avatarUrl = gifUrl; // Intentar primero el GIF animado
        _avatarLoaded = true;
        _gifPreferred = true;
        _triedDefaultAvatar = false; // reset al recargar
        print('👤 [UserAvatar] Estado inicial avatar para "${widget.nick}": _avatarUrl=$_avatarUrl, _staticAvatarUrl=$_staticAvatarUrl');
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
    
    // Detectar si el fallback es URL (emoticono JoyPixels), asset local o emoji/texto
    final isFallbackUrl = fallback.startsWith('http://') || fallback.startsWith('https://');
    final isFallbackAsset = fallback.startsWith('asset:');
    
    // Para usuarios normales, siempre intentar cargar el avatar si tenemos una URL
    // Incluso si _avatarLoaded es false, intentar cargar para que el errorBuilder maneje el fallback
    final shouldTryLoadAvatar = !widget.isRobot && _avatarUrl != null;
    
    // Verificar si el usuario está en away
    final whoisMap = ref.watch(whoisProvider);
    final whoisInfo = whoisMap[widget.nick.toLowerCase()];
    final isAway = whoisInfo?.isAway ?? false;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
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
                      child: _buildFallback(fallback, isFallbackUrl, isFallbackAsset, key: ValueKey('${widget.nick}_loading_${widget.isRobot}')),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    // Estrategia de fallback:
                    // 1) Si estamos intentando GIF, pasar a PNG estático (_staticAvatarUrl)
                    // 2) Si PNG falla, intentar avatar generado por defecto del panel
                    // 3) Si todo falla, usar fallback (emoji / inicial)
                    print('⚠️ [UserAvatar] Error cargando avatar para "${widget.nick}": $error');
                    print('⚠️ [UserAvatar] Stack trace: $stackTrace');

                    final cleanNick = widget.nick.trim();

                    if (_gifPreferred && _staticAvatarUrl != null) {
                      // El GIF ha fallado: cambiar a avatar estático PNG.
                      _gifPreferred = false;
                      final nextUrl = _staticAvatarUrl!;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _avatarUrl = nextUrl;
                            print('🔄 [UserAvatar] Fallback de GIF a PNG estático para "$cleanNick": $_avatarUrl');
                          });
                        }
                      });
                    } else if (!_triedDefaultAvatar) {
                      // El avatar personalizado (GIF o PNG) ha fallado: intentar generador por defecto.
                      _triedDefaultAvatar = true;
                      final defaultUrl = AvatarService.getDefaultAvatarUrl(cleanNick);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _avatarUrl = defaultUrl;
                            print('🔄 [UserAvatar] Fallback a avatar generado por defecto para "$cleanNick": $_avatarUrl');
                          });
                        }
                      });
                    }

                    return _buildFallback(
                      fallback,
                      isFallbackUrl,
                      isFallbackAsset,
                      key: ValueKey('${widget.nick}_error_${widget.isRobot}_${_triedDefaultAvatar ? "default" : "custom"}'),
                    );
                  },
                )
              : _buildFallback(fallback, isFallbackUrl, isFallbackAsset, key: ValueKey('${widget.nick}_fallback_${widget.isRobot}_${_lastRefreshTimestamp ?? 0}')), // Incluir isRobot y timestamp en la clave del fallback
            ),
          ),
        ),
        // Indicador de away
        if (isAway)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: widget.size * 0.3,
              height: widget.size * 0.3,
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.airplanemode_active,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildFallback(String fallback, bool isUrl, bool isAsset, {Key? key}) {
    Widget fallbackWidget;
    if (isAsset && fallback.startsWith('asset:')) {
      final assetPath = fallback.substring(6);
      fallbackWidget = Image.asset(
        assetPath,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
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
    } else if (isUrl) {
      // Si es una URL, mostrar como imagen
      fallbackWidget = Image.network(
        fallback,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
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
