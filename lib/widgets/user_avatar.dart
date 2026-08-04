import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/debug_config.dart';
import '../services/avatar_service.dart';
import '../providers/irc_provider.dart';
import 'robot_avatar.dart';
import 'spinning_avatar_ring.dart';

class UserAvatar extends ConsumerStatefulWidget {
  final String nick;
  final double size;
  final String? fallbackIcon; // Emoji o inicial
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final bool
  isRobot; // Si es true, no intenta cargar avatar de la red, usa directamente el fallback
  final String? roleBadge; // Carácter del modo IRC (~, &, !, @, %, +) para mostrar badge de rol
  final String? auraEmoji; // Emoji de aura para mostrar sobre el avatar

  const UserAvatar({
    super.key,
    required this.nick,
    this.size = 42,
    this.fallbackIcon,
    this.backgroundColor,
    this.gradient,
    this.border,
    this.boxShadow,
    this.isRobot = false,
    this.roleBadge,
    this.auraEmoji,
  });

  @override
  ConsumerState<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends ConsumerState<UserAvatar> {
  String? _avatarUrl;
  String? _staticAvatarUrl;
  String? _canonicalNick;
  int? _lastRefreshTimestamp;
  bool? _lastPreferAnimated;
  bool _triedDefaultAvatar = false;
  bool _gifPreferred = false;
  bool _shouldTryStaticFallback = false;
  bool _imageFailed = false;
  ImageStreamListener? _imageErrorListener;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    // Solo una carga: post-frame callback evita duplicados con _loadAvatar async.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !widget.isRobot &&
          _avatarUrl == null &&
          widget.nick.trim().isNotEmpty) {
        _loadAvatar();
      }
    });
  }

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si cambió el nick, recargar avatar
    if (oldWidget.nick != widget.nick) {
      _avatarUrl = null;
      _lastRefreshTimestamp = null;
      _loadGeneration++;
      _loadAvatar();
    }
    // Si cambió isRobot, recargar avatar (importante: puede cambiar la detección)
    if (oldWidget.isRobot != widget.isRobot) {
      _avatarUrl = null;
      _loadGeneration++;
      _loadAvatar();
    }
  }

  @override
  void dispose() {
    _removeImageErrorListener();
    super.dispose();
  }

  void _removeImageErrorListener() {
    if (_imageErrorListener != null) {
      final provider = _avatarUrl != null ? NetworkImage(_avatarUrl!) : null;
      provider?.resolve(const ImageConfiguration()).removeListener(_imageErrorListener!);
      _imageErrorListener = null;
    }
  }

  void _listenImageError(String url) {
    _removeImageErrorListener();
    _imageFailed = false;
    final provider = NetworkImage(url);
    final stream = provider.resolve(const ImageConfiguration());
    _imageErrorListener = ImageStreamListener(
      (_, __) {},
      onError: (error, stackTrace) {
        if (mounted) {
          _handleAvatarError();
        }
      },
    );
    stream.addListener(_imageErrorListener!);
  }

  void _handleAvatarError() {
    final cleanNick = widget.nick.trim();

    if (_gifPreferred &&
        _shouldTryStaticFallback &&
        _staticAvatarUrl != null &&
        _avatarUrl != _staticAvatarUrl) {
      setState(() {
        _gifPreferred = false;
        _avatarUrl = _staticAvatarUrl;
      });
      return;
    }

    if (!_triedDefaultAvatar) {
      _triedDefaultAvatar = true;
      final defaultUrl = AvatarService.getDefaultAvatarUrl(
        _canonicalNick ?? cleanNick,
      );
      setState(() {
        _avatarUrl = defaultUrl;
      });
      _listenImageError(defaultUrl);
      return;
    }

    setState(() {
      _imageFailed = true;
    });
  }

  String? _lastGlobalGif;

  @override
  Widget build(BuildContext context) {
    try {
      // Observar solo el timestamp de este nick (evita reconstruir todos los avatares del canal)
      final refreshTimestamp = ref.watch(
        avatarRefreshProvider.select((m) => m[widget.nick.toLowerCase()]),
      );

      // Observar cambios en el GIF global (data URL o URL remota) para el propio nick
      final currentNick = ref.read(currentNicknameProvider);
      final globalGif = ref.watch(globalAvatarGifProvider);
      final isOwnNick = currentNick != null &&
          currentNick.toLowerCase() == widget.nick.toLowerCase();
      if (isOwnNick && _lastGlobalGif != globalGif) {
        _lastGlobalGif = globalGif;
        _avatarUrl = null;
        _triedDefaultAvatar = false;
        _imageFailed = false;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadAvatar();
        });
      }

      // Observar el ajuste global de avatares animados para reaccionar al cambio.
      final preferAnimated = ref.watch(
        messageFormatPreferencesProvider.select((p) => p.enableAnimatedAvatars),
      );
      if (_lastPreferAnimated != null &&
          _lastPreferAnimated != preferAnimated) {
        _lastPreferAnimated = preferAnimated;
        _avatarUrl = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadAvatar();
        });
      } else {
        _lastPreferAnimated = preferAnimated;
      }

      // Si el timestamp cambió, recargar el avatar
      if (refreshTimestamp != null &&
          refreshTimestamp != _lastRefreshTimestamp) {
        _lastRefreshTimestamp = refreshTimestamp;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _loadAvatar();
        });
      }

      return _buildAvatarWidget();
    } catch (e) {
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
    final initial = widget.nick.trim().isNotEmpty
        ? widget.nick.trim()[0].toUpperCase()
        : '?';
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        gradient: widget.gradient,
        color: widget.gradient == null
            ? (widget.backgroundColor ?? Colors.grey)
            : null,
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

  /// Resuelve el nick canónico (con el casing real del servidor) buscando en
  /// la lista de usuarios de los canales conocidos. Si no se encuentra,
  /// devuelve el nick de entrada.
  String _resolveCanonicalNick(String nick) {
    final searchLower = nick.toLowerCase();
    final channels = ref.read(channelsProvider);
    for (final channel in channels.values) {
      for (final user in channel.users) {
        if (user.toLowerCase() == searchLower) {
          return user;
        }
      }
    }
    return nick;
  }

  Future<void> _loadAvatar() async {
    final generation = ++_loadGeneration;
    // ignore: avoid_print
    // print('[USER_AVATAR] _loadAvatar: nick="${widget.nick}", isRobot=${widget.isRobot}');
    if (widget.nick.isEmpty) {
      setState(() {});
      return;
    }

    // Limpiar el nick para asegurar que no tenga espacios extra

    // Limpiar el nick para asegurar que no tenga espacios extra
    final cleanNick = widget.nick.trim();
    if (cleanNick.isEmpty) {
      setState(() {});
      return;
    }

    // Si es un robot, no intentar cargar avatar de la red, usar directamente el fallback
    if (widget.isRobot) {
      if (mounted) {
        setState(() {
          _avatarUrl = null; // Forzar uso del fallback
        });
      }
      return;
    }

    // Resolver casing real del nick a partir de la lista de usuarios de los canales.
    // El servidor de avatares hashea el nick case-sensitive, así que un mensaje
    // con "malthael" no encontrará el avatar subido como "Malthael".
    final canonicalNick = _resolveCanonicalNick(cleanNick);
    _canonicalNick = canonicalNick;
    // ignore: avoid_print
    // print('[USER_AVATAR] nick original="${widget.nick}" -> canónico="$canonicalNick"');

    // Leer el ajuste global de avatares animados.
    final preferAnimated = ref.read(messageFormatPreferencesProvider).enableAnimatedAvatars;

    // Buscar la mejor URL de avatar personalizado (subcarpetas 40/80/400,
    // default/gif, o default/png comparado con el generado por defecto).
    final bestUrl = await AvatarService.getBestAvatarUrl(
      canonicalNick,
      preferAnimated: preferAnimated,
    );
    debugLog('[AVATAR-LOAD] nick="${widget.nick}" canonical="$canonicalNick" preferAnimated=$preferAnimated bestUrl=$bestUrl');
    // Descartar resultado obsoleto si una llamada más reciente ya empezó
    if (mounted && generation == _loadGeneration) {
      setState(() {
        _staticAvatarUrl = bestUrl;
        _avatarUrl = bestUrl;
        _gifPreferred = false;
        _shouldTryStaticFallback = false;
        _triedDefaultAvatar = bestUrl == null;
        _imageFailed = false;
      });
      if (bestUrl != null && bestUrl.trim().isNotEmpty) {
        _listenImageError(bestUrl);
      }
    }
  }

  Widget _buildAvatarWidget() {
    // Verificar si hay un icono personalizado para este usuario
    final userIcons = ref.read(userIconsProvider);
    final customIcon = userIcons[widget.nick.toLowerCase()];

    final fallback =
        widget.fallbackIcon ??
        customIcon ??
        (widget.nick.isNotEmpty ? widget.nick[0].toUpperCase() : '?');

    final currentNick = ref.read(currentNicknameProvider);
    final globalGif = ref.watch(globalAvatarGifProvider);
    final isOwnNick = currentNick != null &&
        currentNick.toLowerCase() == widget.nick.toLowerCase();
    // Mostrar el GIF local (data URL) o la URL remota del propio usuario
    final localOwnGif =
        isOwnNick &&
            globalGif != null &&
            globalGif.isNotEmpty
        ? globalGif
        : null;

    // Detectar si el fallback es URL (emoticono JoyPixels), asset local o emoji/texto
    final isFallbackUrl =
        fallback.startsWith('http://') || fallback.startsWith('https://');
    final isFallbackAsset = fallback.startsWith('asset:');

    // Para usuarios normales, intentar cargar el avatar solo si tenemos una URL válida (no vacía)
    final shouldTryLoadAvatar =
        localOwnGif == null &&
        !widget.isRobot &&
        _avatarUrl != null &&
        _avatarUrl!.trim().isNotEmpty;

    // Solo observar away de este nick para evitar rebuilds de todos los avatares
    final isAway = ref.watch(
      whoisProvider.select(
        (m) => m[widget.nick.toLowerCase()]?.isAway ?? false,
      ),
    );

    // Determinar si mostrar imagen de avatar (redonda) o fallback
    final showNetworkAvatar =
        localOwnGif == null && shouldTryLoadAvatar && !_imageFailed;
    final bool isDataUrlGif = localOwnGif != null && localOwnGif.startsWith('data:image/gif;base64,');
    final DecorationImage? backgroundImage =
        localOwnGif != null && isDataUrlGif ? _buildDataUrlDecorationImage(localOwnGif) : null;
    // Si el ownGif es URL remota, mostrarlo como NetworkImage
    final bool showOwnRemoteGif = localOwnGif != null && !isDataUrlGif;
    final showFallback = !showNetworkAvatar && backgroundImage == null && !showOwnRemoteGif && !_imageFailed;

    // Envolver en SizedBox para asegurar que el widget reporte un tamaño
    // intrínseco no nulo. Sin esto, un OverflowBox aislado puede reportar 0
    // de ancho/alto intrínseco y hacer que ListTile colapse el hueco del
    // leading, dejando el avatar centrado y ocultando el nombre.
    final avatarWidget = SizedBox(
      width: widget.size,
      height: widget.size,
      child: OverflowBox(
        minWidth: widget.size,
        maxWidth: widget.size,
        minHeight: widget.size,
        maxHeight: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Fondo circular con imagen (si aplica) o gradiente/fallback
            ClipOval(
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  gradient: showNetworkAvatar || backgroundImage != null || showOwnRemoteGif
                      ? null
                      : widget.gradient,
                  color: showNetworkAvatar || backgroundImage != null || showOwnRemoteGif
                      ? null
                      : (widget.gradient == null ? widget.backgroundColor : null),
                  shape: BoxShape.circle,
                  border: widget.border,
                  boxShadow: widget.boxShadow,
                  image: showNetworkAvatar
                      ? DecorationImage(
                          image: NetworkImage(_avatarUrl!),
                          fit: BoxFit.cover,
                        )
                      : backgroundImage ?? (showOwnRemoteGif
                          ? DecorationImage(
                              image: NetworkImage(localOwnGif!),
                              fit: BoxFit.cover,
                            )
                          : null),
                ),
                child: showFallback
                    ? _buildFallback(fallback, isFallbackUrl, isFallbackAsset)
                    : null,
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
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.airplanemode_active,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            // Badge de rol (overlay sobre el avatar)
            if (widget.roleBadge != null)
              Positioned(
                bottom: 0,
                left: 0,
                child: _buildRoleBadgeOverlay(widget.roleBadge!),
              ),
            // Badge de aura (overlay arriba-derecha del avatar)
            if (widget.auraEmoji != null && widget.auraEmoji!.isNotEmpty)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  width: widget.size * 0.35,
                  height: widget.size * 0.35,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      widget.auraEmoji!,
                      style: TextStyle(fontSize: widget.size * 0.22),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (widget.roleBadge != null) {
      final Color ringColor;
      switch (widget.roleBadge) {
        case '~':
        case '&':
          ringColor = const Color(0xFFFF5252);
          break;
        case '!':
          ringColor = const Color(0xFFFFD740);
          break;
        case '@':
          ringColor = const Color(0xFF2196F3);
          break;
        case '%':
          ringColor = const Color(0xFF4CAF50);
          break;
        default:
          ringColor = const Color(0xFF40C4FF);
      }
      return SpinningAvatarRing(
        color: ringColor,
        ringWidth: 2.5,
        size: widget.size + 6,
        child: avatarWidget,
      );
    }

    return avatarWidget;
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

  DecorationImage? _buildDataUrlDecorationImage(String dataUrl) {
    try {
      final base64Data = dataUrl.contains(',')
          ? dataUrl.substring(dataUrl.indexOf(',') + 1)
          : dataUrl;
      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) return null;
      return DecorationImage(
        image: MemoryImage(Uint8List.fromList(bytes)),
        fit: BoxFit.cover,
      );
    } catch (_) {
      return null;
    }
  }

  Widget _buildFallback(String fallback, bool isUrl, bool isAsset, {Key? key}) {
    Widget fallbackWidget;
    // Robots con icono por defecto (🤖): usar el avatar vectorial moderno.
    if (widget.isRobot && !isUrl && !isAsset && _isDefaultRobotIcon(fallback)) {
      fallbackWidget = Center(
        child: RobotAvatar(size: widget.size, seed: widget.nick),
      );
      return key != null
          ? KeyedSubtree(key: key, child: fallbackWidget)
          : fallbackWidget;
    }
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
        webHtmlElementStrategy: WebHtmlElementStrategy.never,
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
    return key != null
        ? KeyedSubtree(key: key, child: fallbackWidget)
        : fallbackWidget;
  }

  Widget _buildRoleBadgeOverlay(String mode) {
    final badgeSize = widget.size * 0.42;
    final iconData = switch (mode) {
      '~' || '&' => _RoleBadgeData(icon: '👑', color: const Color(0xFFFF5252)),
      '!' => _RoleBadgeData(icon: '🛡️', color: const Color(0xFFFFD740)),
      '@' => _RoleBadgeData(icon: '⚡', color: const Color(0xFF2196F3)),
      '%' => _RoleBadgeData(icon: '🎵', color: const Color(0xFF4CAF50)),
      '+' => _RoleBadgeData(icon: '🎙️', color: const Color(0xFF40C4FF)),
      _ => _RoleBadgeData(icon: '', color: Colors.grey),
    };
    if (iconData.icon.isEmpty) return const SizedBox.shrink();
    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        color: iconData.color.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          iconData.icon,
          style: TextStyle(fontSize: badgeSize * 0.55),
        ),
      ),
    );
  }
}

class _RoleBadgeData {
  final String icon;
  final Color color;
  const _RoleBadgeData({required this.icon, required this.color});
}

bool _isDefaultRobotIcon(String fallback) {
    final trimmed = fallback.trim();
    return trimmed.isEmpty || trimmed == '🤖';
  }
