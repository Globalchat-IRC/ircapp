import 'dart:convert';
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
  bool _shouldTryStaticFallback = false;

  @override
  void initState() {
    super.initState();
    _lastIsRobot = widget.isRobot;
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
    try {
      // Observar solo el timestamp de este nick (evita reconstruir todos los avatares del canal)
      final refreshTimestamp = ref.watch(
        avatarRefreshProvider.select((m) => m[widget.nick.toLowerCase()]),
      );

      // Si el timestamp cambió, recargar el avatar
      if (refreshTimestamp != null && refreshTimestamp != _lastRefreshTimestamp) {
        _lastRefreshTimestamp = refreshTimestamp;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadAvatar();
        });
      }

      // Si cambió isRobot, recargar el avatar inmediatamente
      if (_lastIsRobot != widget.isRobot) {
        _lastIsRobot = widget.isRobot;
        _avatarLoaded = false;
        _avatarUrl = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadAvatar();
        });
      }

      return _buildAvatarWidget();
    } catch (e, st) {
      // Evitar que un error en avatar (p. ej. web/Image.network) rompa la lista de usuarios
      assert(() {
        // ignore: avoid_print
        debugPrint('UserAvatar build error: $e');
        return true;
      }());
      return _buildSafeFallback();
    }
  }

  Widget _buildSafeFallback() {
    final initial = widget.nick.trim().isNotEmpty ? widget.nick.trim()[0].toUpperCase() : '?';
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: widget.gradient,
        color: widget.gradient == null ? (widget.backgroundColor ?? Colors.grey) : null,
        shape: BoxShape.circle,
        border: widget.border,
        boxShadow: widget.boxShadow,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: widget.size * 0.4,
          ),
        ),
      ),
    );
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
      if (mounted) {
        setState(() {
          _avatarUrl = null; // Forzar uso del fallback
          _avatarLoaded = true;
        });
      }
      return;
    }
    
    if (PlatformUtils.isWeb) {
      final staticUrl = AvatarService.getAvatarUrl(cleanNick);
      final gifUrl = AvatarService.getAvatarGifUrl(cleanNick);
      final hasCustomStatic =
          await AvatarService.hasLikelyCustomStaticAvatar(cleanNick);

      if (mounted) {
        setState(() {
          _staticAvatarUrl = staticUrl;
          _gifAvatarUrl = gifUrl;
          _avatarUrl = gifUrl;
          _avatarLoaded = true;
          _gifPreferred = true;
          _shouldTryStaticFallback = hasCustomStatic;
          _triedDefaultAvatar = !hasCustomStatic;
        });
      }
      return;
    }

    final staticUrl = await AvatarService.getCorrectAvatarUrl(cleanNick);
    final gifUrl = AvatarService.getAvatarGifUrl(cleanNick);
    final initialUrl = PlatformUtils.isWeb ? staticUrl : gifUrl;
    if (mounted) {
      setState(() {
        _staticAvatarUrl = staticUrl;
        _gifAvatarUrl = gifUrl;
        _avatarUrl = initialUrl;
        _avatarLoaded = true;
        _gifPreferred = !PlatformUtils.isWeb;
        _triedDefaultAvatar = false;
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

    final currentNick = ref.read(currentNicknameProvider);
    final globalGif = ref.read(globalAvatarGifProvider);
    final localOwnGif = PlatformUtils.isWeb &&
            currentNick != null &&
            currentNick.toLowerCase() == widget.nick.toLowerCase() &&
            globalGif != null &&
            globalGif.startsWith('data:image/gif;base64,')
        ? globalGif
        : null;
    
    // Detectar si el fallback es URL (emoticono JoyPixels), asset local o emoji/texto
    final isFallbackUrl = fallback.startsWith('http://') || fallback.startsWith('https://');
    final isFallbackAsset = fallback.startsWith('asset:');
    
    // Para usuarios normales, intentar cargar el avatar solo si tenemos una URL válida (no vacía)
    final shouldTryLoadAvatar = localOwnGif == null &&
        !widget.isRobot &&
        _avatarUrl != null &&
        _avatarUrl!.trim().isNotEmpty;
    
    // Solo observar away de este nick para evitar rebuilds de todos los avatares
    final isAway = ref.watch(whoisProvider.select((m) => m[widget.nick.toLowerCase()]?.isAway ?? false));
    
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
            child: localOwnGif != null
                ? _buildDataUrlGif(localOwnGif)
                : shouldTryLoadAvatar
                    ? Image.network(
                        _avatarUrl!,
                        width: widget.size,
                        height: widget.size,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        // En web, preferimos <img> HTML para que entren mejor los PNG hash de xmlrpc.
                        webHtmlElementStrategy: PlatformUtils.isWeb
                            ? WebHtmlElementStrategy.prefer
                            : WebHtmlElementStrategy.never,
                        // Durante el refresco mantenemos la imagen anterior para evitar
                        // parpadeos o pequeños saltos visuales en la lista y el chat.
                        loadingBuilder: (context, child, loadingProgress) {
                          return child;
                        },
                        errorBuilder: (context, error, stackTrace) {
                          final cleanNick = widget.nick.trim();
                          if (_gifPreferred &&
                              _shouldTryStaticFallback &&
                              _staticAvatarUrl != null &&
                              _avatarUrl != _staticAvatarUrl) {
                            _gifPreferred = false;
                            final nextUrl = _staticAvatarUrl!;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _avatarUrl = nextUrl);
                            });
                            return const SizedBox.expand();
                          } else if (!_triedDefaultAvatar && !PlatformUtils.isWeb) {
                            _triedDefaultAvatar = true;
                            final defaultUrl = AvatarService.getDefaultAvatarUrl(cleanNick);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => _avatarUrl = defaultUrl);
                            });
                            return const SizedBox.expand();
                          }

                          return _buildFallback(
                            fallback,
                            isFallbackUrl,
                            isFallbackAsset,
                          );
                        },
                      )
                    : _buildFallback(fallback, isFallbackUrl, isFallbackAsset),
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

  Widget _buildDataUrlGif(String dataUrl) {
    try {
      final base64Data = dataUrl.contains(',')
          ? dataUrl.substring(dataUrl.indexOf(',') + 1)
          : dataUrl;
      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) {
        return const SizedBox.shrink();
      }
      return Image.memory(
        Uint8List.fromList(bytes),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return const SizedBox.shrink();
        },
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
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
                fontSize: widget.size * 0.6,
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
                fontSize: widget.size * 0.6,
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
            fontSize: widget.size * 0.6,
          ),
        ),
      );
    }
    return key != null ? KeyedSubtree(key: key, child: fallbackWidget) : fallbackWidget;
  }
}
