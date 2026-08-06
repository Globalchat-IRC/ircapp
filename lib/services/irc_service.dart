import 'dart:async';
import 'package:flutter/widgets.dart';
import '../models/irc_message.dart';
import 'chat_history_service.dart';
import '../models/whois_info.dart';
import '../utils/irc_color_parser.dart';
import 'irc_connection_interface.dart';
import 'irc_connection_factory.dart';
import '../utils/platform_utils.dart';
import '../config/debug_config.dart';
import '../utils/irc_message_limits.dart';
import '../utils/web_lifecycle_listener_stub.dart'
    if (dart.library.html) '../utils/web_lifecycle_listener_web.dart';

class IRCService {
  IRCConnection? _connection;
  String? _currentHost; // Guardar host para serverHost getter
  String? _nickname;
  String?
  _originalNickname; // Guardar el nick original para buscar alternativas
  int _nickAttempts = 0; // Contador de intentos de nick alternativos
  String? _zncUsername; // Usuario ZNC (extraído de username:password)
  String? _currentChannel;
  Map<String, IRCChannel> channels = {};
  final List<Function(IRCMessage)> _messageListeners = [];
  final List<Function(String channel, String pendingId)> _pendingRemovalListeners = [];
  final List<Function(String)> _userListListeners = [];
  final List<Function(String)> _topicListeners = [];
  final List<Function()> _connectionListeners = [];
  final List<Function()> _disconnectionListeners = [];
  final List<Function(WhoisInfo)> _whoisListeners = [];
  final List<Function(String)> _nickChangeListeners =
      []; // Listeners para cambios de nick
  final List<Function(String, String)> _kickListeners =
      []; // Listeners para cuando el usuario es expulsado (channel, reason)
  final List<Function(String channel, String reason, int code)>
      _joinFailListeners = []; // JOIN rechazado (ban, +i, +k, etc.)
  final List<Function()> _ircopListeners =
      []; // Listeners para cuando se identifica como IRCop
  final List<Function(int)> _lagListeners =
      []; // Listeners para actualizaciones de lag
  final List<Function(String)> _debugLogListeners =
      []; // Listeners para logs de debug
  final List<Function(String)> _helpChannelJoinListeners =
      []; // Listeners para cuando entramos a canales de ayuda (#ayuda, #cau)
  final List<Function(String)> _werewolfChannelJoinListeners =
      []; // Listeners para cuando entramos a #werewolf
  final List<Function(bool, String?)> _awayStatusListeners =
      []; // Listeners para cambios de estado de away (isAway, awayMessage)
  final List<Function(String channel, String nick, bool isTyping)>
      _typingListeners = []; // Listeners para CTCP TYPING
  final List<Function(String nick)> _pokeListeners =
      []; // Listeners para CTCP PING (poke/zumbido)
  final List<Function(String nick)> _kissListeners =
      []; // Listeners para ACTION kiss (💋)
  final List<Function(String action, String fromNick)> _actionListeners =
      []; // Listeners para todas las acciones interactivas
  final Map<String, WhoisInfo> _whoisCache = {};
  final Map<String, WhoisInfo> _pendingWhois =
      {}; // Para acumular información de whois
  final Map<String, DateTime> _recentPrivateSends =
      {}; // Última vez que se envió un PM a cada nick (para detectar 401 de envío)
  // Resultados de comandos LIST y WHO
  final List<Map<String, dynamic>> _listResults = []; // Lista de canales
  final List<Map<String, dynamic>> _whoResults = []; // Lista de usuarios de WHO
  final List<Function(List<Map<String, dynamic>>)> _listListeners = [];
  final List<Function(List<Map<String, dynamic>>)> _whoListeners = [];

  // Resultados de comandos IRCop (LINKS, STATS, TRACE, MAP, MOTD, etc.)
  final List<String> _ircopCommandResults =
      []; // Líneas de respuesta de comandos IRCop
  final List<Function(List<String>)> _ircopCommandListeners = [];
  String? _currentIRCOpCommand; // Comando IRCop actual que estamos esperando
  Timer?
  _ircopCommandTimer; // Timer para comandos sin código de fin específico (como REHASH)
  bool _isIRCOp = false; // Cache del estado de IRCop del usuario actual
  final Set<String> _ignoredUsers =
      {}; // Lista de usuarios ignorados (en minúsculas)
  final Map<String, Timer> _pendingMessageTimers =
      {}; // Timers para mensajes pendientes
  final Map<String, Completer<int?>> _statusCheckCompleters =
      {}; // Completers para verificaciones de status
  StreamSubscription? _socketSubscription;
  late Completer<void> _connectionCompleter;
  bool _isConnected = false;
  bool _isRegistered =
      false; // Indica si el usuario está completamente registrado (recibió 001)
  Timer? _lagPingTimer; // Timer para enviar PING periódicamente y medir lag
  DateTime? _lastPingSent; // Timestamp del último PING enviado
  String?
  _lastPingToken; // Token del último PING enviado para identificar la respuesta
  bool _hasAutoJoinedGlobalChat =
      false; // Flag para rastrear si ya se hizo autojoin inicial a #globalchat
  bool _autoJoinOfficialGlobalChat =
      true; // Controla si se hace autojoin al canal oficial #globalchat
  final Set<String> _manuallyClosedChannels =
      {}; // Canales que el usuario cerró manualmente
  Timer?
  _expiredMessagesTimer; // Timer para verificar mensajes expirados periódicamente
  Timer?
  _awayStatusUpdateTimer; // Timer para actualizar estado away de usuarios periódicamente
  final Map<String, DateTime> _lastWhoisCheck =
      {}; // Última vez que se hizo WHOIS para cada usuario
  Timer? _heartbeatWatchdogTimer;
  Timer? _reconnectTimer;
  bool _webLifecycleHandlersRegistered = false;
  Timer? _resumeProbeTimer;
  Timer? _resumeDebounceTimer; // Debounce para eventos rápidos de lifecycle (Chromebook)
  DateTime? _lastServerActivityAt;
  String? _sessionHost;
  int? _sessionPort;
  bool _sessionUseSSL = true;
  String? _sessionNickname;
  String? _sessionIdentifyPassword;
  final List<String> _sessionChannels = [];
  // Canales donde el servidor confirmó nuestro JOIN (eco propio).
  final Set<String> _serverConfirmedChannels = {};
  /// JOIN enviado, aún sin confirmación del servidor (eco JOIN o error).
  final Set<String> _pendingJoinChannels = {};
  bool _autoReconnectEnabled = false;
  bool _isReconnecting = false;
  bool _manualDisconnectRequested = false;
  int _reconnectAttempts = 0;

  // Comprobamos la salud de la conexión con frecuencia para detectar
  // rápidamente caídas silenciosas (proxy/NAT que cierra conexiones inactivas,
  // ping timeout del servidor, etc.).
  static const Duration _heartbeatCheckInterval = Duration(seconds: 15);
  // Si no hay ninguna actividad del servidor (ni PONG a nuestros PING, ni
  // tráfico de otros usuarios) durante este tiempo, consideramos la conexión
  // muerta y forzamos reconexión. 75s ≈ 3-4 PING sin respuesta.
  static const Duration _heartbeatTimeout = Duration(seconds: 75);
  static const Duration _resumeReconnectThreshold = Duration(seconds: 90);
  static const Duration _resumeProbeTimeout = Duration(seconds: 8);
  // Enviamos un PING cada 20s para mantener viva la sesión y la conexión TCP/
  // WebSocket por debajo de los timeouts de inactividad habituales (60s en
  // muchos proxies/NAT), con margen aunque el navegador ralentice algo el timer.
  static const Duration _lagPingInterval = Duration(seconds: 20);

  bool get isConnected => _isConnected;
  bool get isRegistered => _isRegistered;
  String? get currentChannel => _currentChannel;
  String? get nickname => _nickname;
  Map<String, IRCChannel> get allChannels => channels;
  bool get isIRCOp => _isIRCOp;

  bool get _hasActiveConnection =>
      _connection != null && _connection!.isConnected;

  /// Indica si el cliente debe auto-unirse al canal oficial #globalchat
  bool get autoJoinOfficialGlobalChat => _autoJoinOfficialGlobalChat;

  /// Permite activar/desactivar el autojoin al canal oficial #globalchat.
  /// Usado, por ejemplo, desde la versión web leyendo el parámetro
  /// de la URL `joinchanneloficial=false`.
  void setAutoJoinOfficialGlobalChat(bool value) {
    _autoJoinOfficialGlobalChat = value;
    debugLog('🌐 [IRC] Configuración autoJoinOfficialGlobalChat = $value');
  }

  /// Obtiene el host del servidor conectado
  String? get serverHost => _currentHost;

  IRCService() {
    _setupWebVisibilityListener();
  }

  List<String> _normalizeRestorableChannels(Iterable<String> channels) {
    final normalized = <String>[];
    for (final channel in channels) {
      final trimmed = channel.trim();
      if (trimmed.isEmpty || !trimmed.startsWith('#')) continue;
      final key = _normalizeChannelName(trimmed);
      if (!normalized.contains(key)) {
        normalized.add(key);
      }
    }
    return normalized;
  }

  void _trackSessionChannel(String channelName) {
    if (!channelName.startsWith('#')) return;
    final normalized = _normalizeChannelName(channelName);
    _sessionChannels.removeWhere((channel) => channel == normalized);
    _sessionChannels.add(normalized);
  }

  void _untrackSessionChannel(String channelName) {
    if (!channelName.startsWith('#')) return;
    final normalized = _normalizeChannelName(channelName);
    _sessionChannels.removeWhere((channel) => channel == normalized);
  }

  void _setupWebVisibilityListener() {
    if (!PlatformUtils.isWeb) return;
    if (_webLifecycleHandlersRegistered) return;
    _webLifecycleHandlersRegistered = registerWebLifecycleListener((source) {
      unawaited(_revalidateConnectionAfterResume(source));
    });
  }

  void _probeConnectionThenReconnect(String source) {
    if (_manualDisconnectRequested || !_autoReconnectEnabled) return;

    final activityBeforeProbe = _lastServerActivityAt;
    _resumeProbeTimer?.cancel();

    try {
      _lastPingToken = DateTime.now().millisecondsSinceEpoch.toString();
      _lastPingSent = DateTime.now();
      _sendCommand('PING $_lastPingToken');
    } catch (_) {
      _forceReconnect(reason: 'resume_probe_send_failed:$source');
      return;
    }

    _resumeProbeTimer = Timer(_resumeProbeTimeout, () {
      final latestActivity = _lastServerActivityAt;
      final responded =
          latestActivity != null &&
          (activityBeforeProbe == null ||
              latestActivity.isAfter(activityBeforeProbe));

      if (!responded && _isConnected && _hasActiveConnection) {
        debugLog(
          '💔 [IRCService] Sin respuesta tras revalidación $source; forzando reconexión.',
        );
        _forceReconnect(reason: 'resume_probe_timeout:$source');
      }
    });
  }

  Future<void> _revalidateConnectionAfterResume(String source) async {
    if (_manualDisconnectRequested || !_autoReconnectEnabled) return;

    // Debounce: en Chromebook visibility+focus+online disparan en ráfaga
    _resumeDebounceTimer?.cancel();
    _resumeDebounceTimer = Timer(const Duration(seconds: 2), () async {
      await _doRevalidateConnection(source);
    });
  }

  Future<void> _doRevalidateConnection(String source) async {

    final lastActivity = _lastServerActivityAt ?? _lastPingSent;
    final isStale =
        lastActivity == null ||
        DateTime.now().difference(lastActivity) > _resumeReconnectThreshold;

    if (!_isConnected || !_hasActiveConnection) {
      debugLog(
        '🔄 [IRCService] Revalidando conexión tras $source: '
        'isConnected=$_isConnected, active=$_hasActiveConnection, stale=$isStale',
      );
      _forceReconnect(reason: 'resume:$source');
      return;
    }

    if (isStale) {
      debugLog(
        '🔄 [IRCService] Conexión posiblemente dormida tras $source; enviando sonda.',
      );
      _probeConnectionThenReconnect(source);
      return;
    }

    _probeConnectionThenReconnect(source);
  }

  void _startHeartbeatWatchdog() {
    _heartbeatWatchdogTimer?.cancel();
    _heartbeatWatchdogTimer = Timer.periodic(_heartbeatCheckInterval, (_) {
      if (!_isConnected || !_hasActiveConnection) return;

      final now = DateTime.now();
      final lastActivity = _lastServerActivityAt ?? _lastPingSent;
      if (lastActivity != null &&
          now.difference(lastActivity) > _heartbeatTimeout) {
        debugLog(
          '💔 [IRCService] Heartbeat vencido '
          '(${now.difference(lastActivity).inSeconds}s sin actividad).',
        );
        _forceReconnect(reason: 'heartbeat_timeout');
      }
    });
  }

  void _stopHeartbeatWatchdog() {
    _heartbeatWatchdogTimer?.cancel();
    _heartbeatWatchdogTimer = null;
    _resumeProbeTimer?.cancel();
    _resumeProbeTimer = null;
    _resumeDebounceTimer?.cancel();
    _resumeDebounceTimer = null;
  }

  void _scheduleReconnect({String reason = 'unknown'}) {
    if (_manualDisconnectRequested ||
        !_autoReconnectEnabled ||
        _isReconnecting ||
        _sessionHost == null ||
        _sessionPort == null ||
        _sessionNickname == null) {
      return;
    }

    _reconnectTimer?.cancel();
    final attempt = _reconnectAttempts + 1;
    final delaySeconds = attempt <= 1 ? 2 : (1 << (attempt - 1)).clamp(2, 30);

    debugLog(
      '🔄 [IRCService] Programando reconexión #$attempt en ${delaySeconds}s '
      '(motivo: $reason)',
    );

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      unawaited(_performReconnect(reason: reason));
    });
  }

  Future<void> _performReconnect({String reason = 'unknown'}) async {
    if (_manualDisconnectRequested ||
        !_autoReconnectEnabled ||
        _isReconnecting ||
        _sessionHost == null ||
        _sessionPort == null ||
        _sessionNickname == null) {
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    debugLog(
      '🔄 [IRCService] Intentando reconectar (#$_reconnectAttempts) '
      'a $_sessionHost:$_sessionPort como $_sessionNickname '
      '(motivo: $reason)',
    );

    try {
      await _socketSubscription?.cancel();
      _socketSubscription = null;
    } catch (_) {}

    try {
      _connection?.close();
    } catch (_) {}

    _connection = null;
    _isConnected = false;
    _isRegistered = false;
    _currentHost = null;
    _serverConfirmedChannels.clear();
    _pendingJoinChannels.clear();

    try {
      await connect(
        host: _sessionHost!,
        port: _sessionPort!,
        nickname: _sessionNickname!,
        useSSL: _sessionUseSSL,
      );
      await waitForRegistration();

      _reconnectAttempts = 0;
      _isReconnecting = false;
      _restoreSessionAfterReconnect();
    } catch (e) {
      _isReconnecting = false;
      debugLog('❌ [IRCService] Falló la reconexión: $e');
      _scheduleReconnect(reason: 'retry_after_failure');
    }
  }

  void _restoreSessionAfterReconnect() {
    final identifyPassword = _sessionIdentifyPassword;
    if (identifyPassword != null && identifyPassword.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (_isConnected && _hasActiveConnection) {
          debugLog(
            '🔐 [IRCService] Restaurando identificación NickServ tras reconexión',
          );
          identifyNick(identifyPassword);
        }
      });
    }

    final channelsToRestore = List<String>.from(_sessionChannels);
    for (var i = 0; i < channelsToRestore.length; i++) {
      final channel = channelsToRestore[i];
      Future.delayed(Duration(milliseconds: 3200 + (i * 450)), () {
        if (_isConnected && _hasActiveConnection) {
          debugLog(
            '🚪 [IRCService] Restaurando canal tras reconexión: $channel',
          );
          joinChannel(channel);
        }
      });
    }
  }

  void _forceReconnect({String reason = 'unknown'}) {
    if (_manualDisconnectRequested || !_autoReconnectEnabled) return;

    try {
      _socketSubscription?.cancel();
      _socketSubscription = null;
    } catch (_) {}

    try {
      _connection?.close();
    } catch (_) {}

    _onDisconnect(scheduleReconnect: true, reason: reason);
  }

  void configureSessionRecovery({
    required bool autoReconnectEnabled,
    String? identifyPassword,
    List<String>? channelsToRestore,
  }) {
    _autoReconnectEnabled = autoReconnectEnabled;
    _sessionIdentifyPassword = identifyPassword?.trim().isNotEmpty == true
        ? identifyPassword!.trim()
        : null;

    if (channelsToRestore != null) {
      _sessionChannels
        ..clear()
        ..addAll(_normalizeRestorableChannels(channelsToRestore));
    }
  }

  void handleAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_revalidateConnectionAfterResume('app_resumed'));
    }
  }

  /// Espera el mensaje 001 del servidor antes de hacer JOIN o navegar al chat.
  Future<void> waitForRegistration({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (_isRegistered) return;
    await _connectionCompleter.future.timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException(
          'El servidor no confirmó el registro IRC (001) a tiempo',
          timeout,
        );
      },
    );
  }

  /// Espera conexión registrada y estable (p. ej. tras volver del carrete en iOS).
  Future<bool> waitForSendReady({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_hasActiveConnection && _isRegistered && !_isReconnecting) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    return _hasActiveConnection && _isRegistered && !_isReconnecting;
  }

  /// Garantiza JOIN confirmado por el servidor antes de PRIVMSG a canal.
  Future<bool> ensureJoinedChannel(
    String channel, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final normalized = _normalizeChannelName(channel);
    if (!normalized.startsWith('#')) return true;

    if (!await waitForSendReady(timeout: timeout)) {
      debugLog('⚠️ [IRCService] ensureJoinedChannel: conexión no lista');
      return false;
    }

    if (_channelJoinConfirmed(normalized)) return true;

    debugLog(
      '⚠️ [IRCService] Re-JOIN en $normalized antes de enviar (sin eco previo)',
    );
    _doJoinChannel(normalized);

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_channelJoinConfirmed(normalized)) return true;
      await Future.delayed(const Duration(milliseconds: 150));
    }

    debugLog('⚠️ [IRCService] Timeout esperando JOIN en $normalized');
    return false;
  }

  bool _isListedInChannelUsers(String normalized) {
    final nick = _nickname;
    if (nick == null) return false;
    final channelObj = channels[normalized];
    if (channelObj == null) return false;
    final nickLower = nick.toLowerCase();
    return channelObj.users.any((u) => u.toLowerCase() == nickLower);
  }

  bool isChannelJoined(String channelName) {
    return _channelJoinConfirmed(_normalizeChannelName(channelName));
  }

  bool isJoinPending(String channelName) {
    return _pendingJoinChannels.contains(_normalizeChannelName(channelName));
  }

  /// Quita un canal creado localmente sin confirmación del servidor (JOIN fallido).
  void abandonLocalChannel(String channelName) {
    final normalized = _normalizeChannelName(channelName);
    _pendingJoinChannels.remove(normalized);
    _serverConfirmedChannels.remove(normalized);
    _untrackSessionChannel(normalized);
    channels.remove(normalized);
    if (_getChannelKey(_currentChannel) == normalized) {
      _currentChannel = null;
    }
    _notifyUserListListeners(normalized);
  }

  void _handleJoinRejected(String channel, String reason, int code) {
    final normalized = _normalizeChannelName(channel);
    debugLog(
      '🚫 [IRC] JOIN rechazado en $normalized (código $code): $reason',
    );
    abandonLocalChannel(normalized);
    for (var listener in _joinFailListeners) {
      try {
        listener(normalized, reason, code);
      } catch (e) {
        debugLog('⚠️ [IRCService] Error en listener de JOIN fallido: $e');
      }
    }
  }

  static String joinRejectTitle(int code) {
    switch (code) {
      case 474:
        return 'Baneado del canal';
      case 471:
      case 473:
        return 'Canal solo por invitación';
      case 475:
        return 'Clave de canal incorrecta';
      case 477:
        return 'Nick registrado requerido';
      case 404:
        return 'No puedes acceder al canal';
      default:
        return 'No puedes entrar al canal';
    }
  }


  bool _shouldAutoConfirmPending(String message) {
    final trimmed = message.trim().toLowerCase();
    // ponytail: URLs de media exigen eco del servidor; auto-confirm da falso positivo
    return !trimmed.startsWith('http://') && !trimmed.startsWith('https://');
  }

  void _removePendingMatchingMessage(String normalized, String message) {
    final channelObj = channels[normalized];
    if (channelObj == null) return;
    for (var i = channelObj.messages.length - 1; i >= 0; i--) {
      final msg = channelObj.messages[i];
      if (msg.isPending && _multilineMessagesMatch(msg.message, message)) {
        if (msg.pendingId != null) {
          removePendingMessage(normalized, msg.pendingId!);
        } else {
          channelObj.messages.removeAt(i);
        }
        return;
      }
    }
  }

  void _failLatestPendingInChannel(String normalized) {
    final channelObj = channels[normalized];
    if (channelObj == null) return;
    for (var i = channelObj.messages.length - 1; i >= 0; i--) {
      final msg = channelObj.messages[i];
      if (msg.isPending && msg.pendingId != null) {
        removePendingMessage(normalized, msg.pendingId!);
        return;
      }
    }
  }

  Future<bool> _awaitMessageEcho(
    String normalized,
    String message, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final channelObj = channels[normalized];
      if (channelObj != null) {
        final stillPending = channelObj.messages.any(
          (m) =>
              m.isPending &&
              m.nick.toLowerCase() == (_nickname ?? '').toLowerCase() &&
              _multilineMessagesMatch(m.message, message),
        );
        if (!stillPending) {
          return channelObj.messages.any(
            (m) =>
                !m.isPending &&
                m.nick.toLowerCase() == (_nickname ?? '').toLowerCase() &&
                _multilineMessagesMatch(m.message, message),
          );
        }
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    _removePendingMatchingMessage(normalized, message);
    return false;
  }

  /// Envía al canal y espera eco del servidor (obligatorio para URLs de media).
  Future<bool> sendMessageAwaitingEcho(
    String channel,
    String message, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final normalized = _normalizeChannelName(channel);
    if (!await ensureJoinedChannel(normalized, timeout: timeout)) return false;
    if (!sendMessage(normalized, message, delaySeconds: 0)) return false;
    return _awaitMessageEcho(normalized, message, timeout: timeout);
  }

  /// Envía PM y espera eco del servidor (obligatorio para URLs de media).
  Future<bool> sendPrivateMessageAwaitingEcho(
    String nick,
    String message, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final normalizedNick = nick.trim();
    if (normalizedNick.isEmpty) return false;
    final queryChannel = normalizedNick.toLowerCase();
    if (!sendPrivateMessage(normalizedNick, message, delaySeconds: 0)) {
      return false;
    }
    return _awaitMessageEcho(queryChannel, message, timeout: timeout);
  }

  Future<void> _openConnection(
    String host,
    int port, {
    required bool useSSL,
    int attempts = 3,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        await _connection!.connect(host, port, useSSL: useSSL);
        debugLog(
          '✅ [IRCService] Connection established to $host:$port '
          '(intento $attempt/$attempts) using ${_connection.runtimeType}',
        );
        return;
      } catch (e) {
        lastError = e;
        debugLog(
          '❌ [IRCService] Connection failed to $host:$port '
          '(intento $attempt/$attempts): $e',
        );
        try {
          await _connection?.disconnect();
        } catch (_) {}
        if (attempt < attempts) {
          await Future.delayed(Duration(milliseconds: 400 * attempt));
          _connection = IRCConnectionFactory.create();
        }
      }
    }
    throw lastError ?? StateError('No se pudo conectar a $host:$port');
  }

  Future<void> connect({
    required String host,
    required int port,
    required String nickname,
    bool useSSL = true,
    String? zncPassword,
  }) async {
    try {
      _manualDisconnectRequested = false;
      _reconnectTimer?.cancel();

      // ponytail: evitar sockets huérfanos si connect() se llama estando ya conectado.
      // Hay que ESPERAR el cierre del socket viejo (disconnect() es async); con el
      // close() fire-and-forget el socket seguía vivo y el servidor rechazaba el
      // re-registro por nick en uso, dejando la app en "Conectando...".
      if (_connection != null) {
        debugLog(
          '📡 [IRCService.connect] Cerrando conexión previa antes de abrir otra',
        );
        final previous = _connection;
        _connection = null;
        _isConnected = false;
        _isRegistered = false;
        _currentHost = null;
        try {
          await _socketSubscription?.cancel();
        } catch (_) {}
        _socketSubscription = null;
        try {
          await previous?.disconnect();
        } catch (_) {}
        // Margen para que el servidor libere el nick del socket anterior.
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _sessionHost = host;
      _sessionPort = port;
      _sessionUseSSL = useSSL;
      _currentHost = host;
      // Limpiar el nick antes de asignarlo (eliminar espacios y guiones al final)
      final cleanNick = nickname.trim();
      debugLog(
        '📡 [IRCService.connect] Connecting to $host:$port as $cleanNick (SSL: $useSSL)',
      );
      debugLog(
        '📡 [IRCService.connect] Platform: ${PlatformUtils.isWeb ? "Web" : "Native"}',
      );
      debugLog(
        '📡 [IRCService.connect] Nick original: "$nickname" -> Limpio: "$cleanNick"',
      );
      _nickname = cleanNick;
      _sessionNickname = cleanNick;
      _originalNickname = cleanNick; // Guardar el nick original
      _nickAttempts = 0; // Resetear contador de intentos
      _zncUsername = null; // Resetear usuario ZNC
      _isRegistered = false; // Reset registration status
      _connectionCompleter = Completer<void>(); // Reinicializar el completer
      _lastServerActivityAt = DateTime.now();

      // Crear conexión apropiada para la plataforma
      _connection = IRCConnectionFactory.create();
      debugLog('📡 [IRCService] Connection type: ${_connection.runtimeType}');
      debugLog(
        '📡 [IRCService] PlatformUtils.canUseNativeSockets: ${PlatformUtils.canUseNativeSockets}',
      );
      debugLog(
        '📡 [IRCService] PlatformUtils.mustUseWebSocket: ${PlatformUtils.mustUseWebSocket}',
      );

      // Host de respaldo si falla el servidor elegido (todos los nodos detrás)
      const String fallbackHost = 'irc.globalchat.org';
      const int fallbackPort = 6667;

      // Conectar usando la interfaz abstracta; reintentar el host elegido antes del fallback.
      try {
        await _openConnection(host, port, useSSL: useSSL);
        _sessionHost = host;
        _sessionPort = port;
      } catch (e) {
        debugLog('❌ [IRCService] Connection failed to $host:$port tras reintentos: $e');
        if (host == fallbackHost) {
          debugLog('❌ [IRCService] Fallback host also failed.');
          rethrow;
        }
        debugLog(
          '🔄 [IRCService] Retrying with $fallbackHost:$fallbackPort...',
        );
        try {
          await _connection?.disconnect();
        } catch (_) {}
        _connection = IRCConnectionFactory.create();
        _currentHost = fallbackHost;
        try {
          await _openConnection(
            fallbackHost,
            fallbackPort,
            useSSL: false,
            attempts: 2,
          );
          debugLog(
            '✅ [IRCService] Connection established to $fallbackHost:$fallbackPort (fallback)',
          );
          _sessionHost = fallbackHost;
          _sessionPort = fallbackPort;
          _sessionUseSSL = false;
        } catch (e2) {
          debugLog('❌ [IRCService] Fallback connection also failed: $e2');
          rethrow;
        }
      }

      // Start listening to incoming data (non-blocking)
      // El stream ya devuelve String, no necesita decodificación
      _socketSubscription = _connection!.stream.listen(
        (String data) {
          try {
            _handleData(data);
          } catch (e, stack) {
            debugLog('❌ [IRCService] Error procesando datos: $e\n$stack');
          }
        },
        onDone: () {
          // debugLog('⛔ [IRCService] Connection closed');
          _onDisconnect(reason: 'stream_done');
        },
        onError: (error) {
          debugLog('❌ [IRCService] Stream error: $error');
          _onDisconnect(reason: 'stream_error');
        },
      );

      // Send initial IRC commands
      // Para ZNC, enviar PASS primero (antes de NICK)
      // Formato ZNC: usuario:contraseña
      if (zncPassword != null && zncPassword.isNotEmpty) {
        final zncPass = zncPassword;
        // Extraer el username de ZNC (formato: username:password)
        final parts = zncPassword.split(':');
        if (parts.isNotEmpty) {
          _zncUsername = parts[0];
          debugLog('📡 [IRCService] ZNC Username extraído: $_zncUsername');
        }
        debugLog(
          '📡 [IRCService] Enviando QUOTE PASS (ZNC) antes de NICK: $zncPass',
        );
        _sendCommand('QUOTE PASS $zncPass');
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Para ZNC, usar el username de ZNC como nick inicial
      final nickToSend = (_zncUsername != null && _zncUsername!.isNotEmpty)
          ? _zncUsername!
          : _nickname!;

      // Actualizar _nickname si es ZNC para mantener consistencia
      if (_zncUsername != null && _zncUsername!.isNotEmpty) {
        _nickname = _zncUsername;
        _sessionNickname = _zncUsername;
      }

      // Usar el nick limpio (ya está en _nickname)
      debugLog(
        '📡 [IRCService] Enviando NICK: "$nickToSend" (ZNC: ${_zncUsername != null})',
      );
      _sendCommand('NICK $nickToSend');

      // Comando USER con formato correcto: USER username hostname servername :realname
      // El servidor rechaza conexiones que parecen bots, así que usamos valores más realistas
      // username: usar una parte del nickname pero más específica para evitar "user" genérico
      String cleanUsername;
      final nickLower = _nickname!.toLowerCase();

      // Intentar extraer parte alfabética del nick
      final alphaPart = nickLower.replaceAll(RegExp(r'[^a-zA-Z]'), '');

      if (alphaPart.isNotEmpty && alphaPart.length >= 3) {
        // Si hay al menos 3 letras, usar esa parte (máximo 8 caracteres)
        cleanUsername = alphaPart.length > 8
            ? alphaPart.substring(0, 8)
            : alphaPart;
      } else {
        // Si no hay suficientes letras, usar "ircapp" en lugar de "user" genérico
        cleanUsername = 'ircapp';
      }

      // realname: algo descriptivo pero no genérico
      final realname = '$_nickname - IRC App';
      _sendCommand('USER $cleanUsername 0 * :$realname');

      debugLog(
        '✅ [IRCService] Commands sent: NICK $_nickname, USER $cleanUsername 0 * :$realname',
      );
      // debugLog('✅ [IRCService] Listener registered');

      // Set connection as established
      _isConnected = true;
      _startLagPingTimer();
      _startHeartbeatWatchdog();
      _startExpiredMessagesTimer();
      _startAwayStatusUpdateTimer();

      // Notify listeners
      // debugLog('📢 [IRCService] Notifying listeners');
      for (var listener in _connectionListeners) {
        listener();
      }

      // debugLog('✅ [IRCService.connect] Connection completed and returned');
    } catch (e) {
      // debugLog('❌ [IRCService] Fatal connection error: $e');
      _isConnected = false;
      rethrow;
    }
  }

  Future<void> disconnect() async {
    _manualDisconnectRequested = true;
    _reconnectTimer?.cancel();
    _isReconnecting = false;
    if (_connection != null) {
      if (_connection!.isConnected) {
        try {
          _sendCommand('QUIT :Goodbye');
        } catch (_) {}
      }
      try {
        await _socketSubscription?.cancel();
      } catch (_) {}
      _socketSubscription = null;
      // Cancelar todos los timers pendientes
      for (final timer in _pendingMessageTimers.values) {
        timer.cancel();
      }
      _pendingMessageTimers.clear();
      _recentPrivateSends.clear();
      try {
        await _connection!.disconnect();
      } catch (_) {}
      _connection = null;
      _isConnected = false;
      _isRegistered = false;
      _currentHost = null;
    }
    // Limpiar estado de sesión para que la próxima conexión empiece limpia.
    channels.clear();
    _currentChannel = null;
    _sessionChannels.clear();
    _serverConfirmedChannels.clear();
    _pendingJoinChannels.clear();
    // Detener timers
    _stopLagPingTimer();
    _stopHeartbeatWatchdog();
    _stopExpiredMessagesTimer();
    _stopAwayStatusUpdateTimer();
    // Resetear flags de autojoin al desconectar
    _hasAutoJoinedGlobalChat = false;
    _manuallyClosedChannels.clear();
    // Resetear nick
    _nickname = null;
    _originalNickname = null;
    _nickAttempts = 0;
    _lastServerActivityAt = null;
  }

  // Normalizar nombre de canal (case-insensitive, sin espacios)
  String _normalizeChannelName(String channelName) {
    if (channelName.isEmpty) return channelName;

    // Remover espacios y normalizar
    channelName = channelName.trim();

    // Remover cualquier ':' al inicio o después de espacios (puede venir de algunos mensajes IRC)
    while (channelName.startsWith(':')) {
      channelName = channelName.substring(1).trim();
    }

    // Remover cualquier '#' duplicado al inicio
    while (channelName.startsWith('##')) {
      channelName = channelName.substring(1);
    }

    // Asegurar que empiece con # (solo uno)
    if (!channelName.startsWith('#')) {
      channelName = '#$channelName';
    }

    // Convertir a minúsculas para comparación (IRC es case-insensitive para canales)
    final normalized = channelName.toLowerCase();

    // Validación final: debe empezar con # y no tener : después
    if (!normalized.startsWith('#') || normalized.contains(':#')) {
      // debugLog('🔍 [DEBUG] ⚠️  Invalid channel name after normalization: "$normalized" (original: "$channelName")');
      // Intentar limpiar más agresivamente
      var cleaned = normalized.replaceAll(':#', '#').replaceAll('::', ':');
      if (cleaned.startsWith(':')) {
        cleaned = cleaned.substring(1);
      }
      if (!cleaned.startsWith('#')) {
        cleaned = '#$cleaned';
      }
      return cleaned.toLowerCase();
    }

    return normalized;
  }

  // Obtener la clave del canal normalizada (para búsqueda case-insensitive)
  String? _getChannelKey(String? channelName) {
    if (channelName == null || channelName.isEmpty) return null;
    return _normalizeChannelName(channelName);
  }

  void joinChannel(String channelName) {
    if (channelName.isEmpty) return;

    // Normalizar el nombre del canal
    final normalized = _normalizeChannelName(channelName);
    if (_channelJoinConfirmed(normalized)) {
      _currentChannel = normalized;
      return;
    }
    _trackSessionChannel(normalized);

    // debugLog('🔍 [DEBUG] joinChannel called with: "$channelName" -> normalized: "$normalized"');
    // debugLog('🔍 [DEBUG] User registered status: $_isRegistered');

    // Si el usuario no está registrado todavía, esperar un poco más
    if (!_isRegistered) {
      // debugLog('🔍 [DEBUG] ⚠️  User not registered yet, waiting for 001 message...');
      Future.delayed(const Duration(milliseconds: 2000), () {
        if (_isRegistered) {
          // debugLog('🔍 [DEBUG] ✅ User now registered, joining channel');
          _doJoinChannel(normalized);
        } else {
          // debugLog('🔍 [DEBUG] ⚠️  Still not registered, trying anyway...');
          _doJoinChannel(normalized);
        }
      });
    } else {
      _doJoinChannel(normalized);
    }
  }

  void _doJoinChannel(String normalized) {
    debugLog('🚪 [IRC] Intentando unirse al canal: $normalized');
    debugLog(
      '🚪 [IRC] Estado: isRegistered=$_isRegistered, isConnected=$_isConnected',
    );
    _pendingJoinChannels.add(normalized);
    _currentChannel = normalized;
    _sendCommand('JOIN $normalized');
    debugLog('🚪 [IRC] Comando JOIN enviado: JOIN $normalized');

    // Auto-confirm pending join after timeout (fixes stuck loading for new channels)
    Future.delayed(const Duration(seconds: 8), () {
      if (_pendingJoinChannels.contains(normalized) && !_serverConfirmedChannels.contains(normalized)) {
        debugLog('⚠️ [IRC] JOIN pending for $normalized after 8s, auto-confirming');
        _serverConfirmedChannels.add(normalized);
        _pendingJoinChannels.remove(normalized);
        _notifyUserListListeners(normalized);
      }
    });

    // Initialize channel if not exists (usar nombre normalizado)
    if (!channels.containsKey(normalized)) {
      channels[normalized] = IRCChannel(name: normalized);
      // ponytail: avisar al provider en cuanto creamos el canal localmente,
      // no solo cuando llega el eco JOIN del servidor.
      _notifyUserListListeners(normalized);
    } else {
      // debugLog('🔍 [DEBUG] Channel already exists: $normalized');
    }

    // Solicitar la lista de usuarios y el TOPIC después de unirse
    // Usar múltiples intentos para asegurar que se reciba la lista
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isConnected && _hasActiveConnection) {
        // debugLog('🔍 [DEBUG] Requesting NAMES for $normalized (first attempt)');
        _sendCommand('NAMES $normalized');
        // debugLog('🔍 [DEBUG] Requesting TOPIC for $normalized (first attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (_isConnected && _hasActiveConnection) {
        // debugLog('🔍 [DEBUG] Requesting NAMES for $normalized (second attempt)');
        _sendCommand('NAMES $normalized');
        // debugLog('🔍 [DEBUG] Requesting TOPIC for $normalized (second attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (_isConnected && _hasActiveConnection) {
        // debugLog('🔍 [DEBUG] Requesting NAMES for $normalized (third attempt)');
        _sendCommand('NAMES $normalized');
        // debugLog('🔍 [DEBUG] Requesting TOPIC for $normalized (third attempt)');
        _sendCommand('TOPIC $normalized');
      }
    });
  }

  void partChannel(String channelName) {
    final normalized = _normalizeChannelName(channelName);
    _untrackSessionChannel(normalized);
    _sendCommand('PART $normalized');
    _serverConfirmedChannels.remove(normalized);
    channels.remove(normalized);
    final currentNormalized = _getChannelKey(_currentChannel);
    if (currentNormalized == normalized) {
      _currentChannel = null;
    }
    // Si el usuario cierra #globalchat manualmente, marcarlo para no volver a abrirlo automáticamente
    if (normalized.toLowerCase() == '#globalchat') {
      _manuallyClosedChannels.add(normalized.toLowerCase());
      debugLog(
        '🌐 [IRC] #globalchat cerrado manualmente, no se volverá a abrir automáticamente',
      );
    }
  }

  /// Separador interno para enviar varias líneas en un único PRIVMSG de IRC.
  static const String _multilineWireSeparator = '\u001E';

  String _encodeMultilineForWire(String message) {
    return message
        .replaceAll('\r\n', '\n')
        .replaceAll('\n', _multilineWireSeparator);
  }

  String _decodeMultilineFromWire(String message) {
    return message.replaceAll(_multilineWireSeparator, '\n');
  }

  String _normalizeMultilineForCompare(String message) {
    return _decodeMultilineFromWire(message).replaceAll('\r\n', '\n').trim();
  }

  bool _multilineMessagesMatch(String a, String b) {
    final left = _normalizeMultilineForCompare(a);
    final right = _normalizeMultilineForCompare(b);
    if (left.isEmpty && right.isEmpty) return true;
    if (left == right) return true;
    if (left.contains(right) || right.contains(left)) return true;
    return false;
  }

  bool _sendWirePrivmsg(
    String target,
    String message, {
    String? replyToMessageId,
  }) {
    final payload = _encodeMultilineForWire(message);
    if (payload.trim().isEmpty) return false;
    final suffix = replyToMessageId != null ? ' [reply:$replyToMessageId]' : '';
    // El [reply:...] sólo debe ir en el primer trozo, así que reservamos sus
    // bytes únicamente para ese cálculo.
    final firstMaxBytes = ircPrivmsgMaxPayloadBytes(
      target,
      extraSuffix: suffix,
    );
    final restMaxBytes = ircPrivmsgMaxPayloadBytes(target);

    // Partir respetando el límite del protocolo (varios PRIVMSG si hace falta).
    var remaining = payload;
    var isFirst = true;
    var sent = true;
    while (remaining.isNotEmpty) {
      final maxBytes = isFirst ? firstMaxBytes : restMaxBytes;
      final chunks = chunkUtf8ByBytes(remaining, maxBytes);
      var chunk = chunks.first;
      remaining = remaining.substring(chunk.length);
      if (isFirst && suffix.isNotEmpty) {
        chunk = '$chunk$suffix';
      }
      sent = _trySendCommand('PRIVMSG $target :$chunk') && sent;
      isFirst = false;
    }
    return sent;
  }

  void _sendWireNotice(String target, String message) {
    final payload = _encodeMultilineForWire(message);
    if (payload.trim().isEmpty) return;
    final maxBytes = ircNoticeMaxPayloadBytes(target);
    for (final chunk in chunkUtf8ByBytes(payload, maxBytes)) {
      if (chunk.isEmpty) continue;
      _sendCommand('NOTICE $target :$chunk');
    }
  }

  bool sendMessage(
    String channel,
    String message, {
    int delaySeconds = 0,
    String? replyToMessageId,
  }) {
    if (!_hasActiveConnection || !_isRegistered || _isReconnecting) {
      debugLog(
        '⚠️ [IRCService] sendMessage abortado: conexión no lista '
        '(active=$_hasActiveConnection, registered=$_isRegistered, '
        'reconnecting=$_isReconnecting)',
      );
      return false;
    }

    final normalized = _normalizeChannelName(channel);

    if (normalized.startsWith('#') && !_channelJoinConfirmed(normalized)) {
      if (_manuallyClosedChannels.contains(normalized.toLowerCase())) {
        debugLog(
          '⚠️ [IRCService] sendMessage abortado: canal cerrado manualmente: $normalized',
        );
        return false;
      }
      debugLog(
        '⚠️ [IRCService] sendMessage abortado: sin JOIN confirmado en $normalized',
      );
      _doJoinChannel(normalized);
      return false;
    }

    // Enviar por la red PRIMERO; solo agregar localmente si el envío fue exitoso
    // Los CTCP GIFT se envían como mensaje normal con prefijo invisible
    // porque UnrealIRCd no retransmite CTCP no-ACTION a canales.
    final isCtcpGift = message.startsWith('\x01GIFT ') && message.endsWith('\x01');
    final wireMessage = isCtcpGift
        ? '\u200B${message.substring(1, message.length - 1)}\u200B' // \x01 → \u200B
        : message;
    final sent = _sendWirePrivmsg(
      normalized,
      wireMessage,
      replyToMessageId: replyToMessageId,
    );
    if (!sent) {
      return false;
    }

    if (channels.containsKey(normalized)) {
      // Los mensajes CTCP (excepto ACTION) no se agregan como texto visible
      // porque el contenido raw (\x01...\x01) no debería mostrarse en el chat.
      // Pero sí notificamos a los listeners para que el UI muestre popups (ej: GIFT).
      final isCtcpNonAction = message.startsWith('\x01') &&
          !message.startsWith('\x01ACTION ') &&
          message.endsWith('\x01');
      if (!isCtcpNonAction) {
        final msg = IRCMessage(
          nick: _nickname ?? 'You',
          channel: normalized,
          message: message,
          timestamp: DateTime.now(),
          isPending: false,
          messageId: IRCMessage.generateMessageId(),
          replyToMessageId: replyToMessageId,
        );
        channels[normalized]!.addMessage(msg);
        _notifyMessageListeners(msg);
      } else {
        // CTCP no-ACTION: notificar listeners sin agregar al historial
        final msg = IRCMessage(
          nick: _nickname ?? 'You',
          channel: normalized,
          message: message,
          timestamp: DateTime.now(),
          isPending: false,
          messageId: IRCMessage.generateMessageId(),
        );
        _notifyMessageListeners(msg);
      }
    }

    return true;
  }

  // Eliminar un mensaje pendiente antes de que llegue al servidor
  bool removePendingMessage(String channel, String pendingId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) {
      return false;
    }

    // Cancelar el timer si existe
    final timer = _pendingMessageTimers.remove(pendingId);
    if (timer != null) {
      timer.cancel();
      // debugLog('⏱️  [IRCService] Timer cancelado para mensaje: $pendingId');
    }

    final channelObj = channels[normalized]!;
    final index = channelObj.messages.indexWhere(
      (msg) => msg.isPending && msg.pendingId == pendingId,
    );

    if (index != -1) {
      channelObj.messages.removeAt(index);
      // Notificar a los listeners de eliminación de pending para que
      // el provider lo retire del estado sin duplicar otros mensajes.
      for (var listener in _pendingRemovalListeners) {
        listener(normalized, pendingId);
      }
      return true;
    }

    return false;
  }

  // Forzar el envío inmediato del mensaje pendiente más reciente en un canal
  bool forceSendPendingMessage(String channel) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) {
      return false;
    }

    final channelObj = channels[normalized]!;
    // Buscar el mensaje pendiente más reciente
    final pendingMessages = channelObj.messages
        .where((msg) => msg.isPending && msg.pendingId != null)
        .toList();
    if (pendingMessages.isEmpty) {
      // debugLog('⚠️  [IRCService] No hay mensajes pendientes para forzar envío');
      return false;
    }

    // Ordenar por timestamp (más reciente primero) y tomar el primero
    pendingMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final pendingMsg = pendingMessages.first;
    final pendingId = pendingMsg.pendingId!;

    // debugLog('⚡ [IRCService] Forzando envío inmediato del mensaje: $pendingId');

    // Cancelar el timer si existe
    final timer = _pendingMessageTimers.remove(pendingId);
    if (timer != null) {
      timer.cancel();
      // debugLog('⏱️  [IRCService] Timer cancelado para forzar envío: $pendingId');
    }

    // Enviar el mensaje inmediatamente
    final message = pendingMsg.message;
    _sendWirePrivmsg(normalized, message);

    // NO confirmar aquí - esperar a que el servidor devuelva el PRIVMSG
    // confirmPendingMessage(normalized, message, DateTime.now());
    // debugLog('✅ [IRCService] Mensaje enviado inmediatamente: $pendingId (esperando confirmación del servidor)');
    return true;
  }

  // Forzar el envío inmediato de un mensaje privado pendiente
  bool forceSendPendingPrivateMessage(String nick) {
    final normalized = nick.toLowerCase();
    if (!channels.containsKey(normalized)) {
      return false;
    }

    final channelObj = channels[normalized]!;
    // Buscar el mensaje pendiente más reciente
    final pendingMessages = channelObj.messages
        .where((msg) => msg.isPending && msg.pendingId != null)
        .toList();
    if (pendingMessages.isEmpty) {
      // debugLog('⚠️  [IRCService] No hay mensajes privados pendientes para forzar envío');
      return false;
    }

    // Ordenar por timestamp (más reciente primero) y tomar el primero
    pendingMessages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final pendingMsg = pendingMessages.first;
    final pendingId = pendingMsg.pendingId!;

    // debugLog('⚡ [IRCService] Forzando envío inmediato del mensaje privado: $pendingId');

    // Cancelar el timer si existe
    final timer = _pendingMessageTimers.remove(pendingId);
    if (timer != null) {
      timer.cancel();
      // debugLog('⏱️  [IRCService] Timer cancelado para forzar envío privado: $pendingId');
    }

    // Enviar el mensaje inmediatamente
    final message = pendingMsg.message;
    _sendWirePrivmsg(normalized, message);

    // Confirmar el mensaje inmediatamente
    confirmPendingMessage(normalized, message, DateTime.now());
    // debugLog('✅ [IRCService] Mensaje privado enviado inmediatamente: $pendingId');
    return true;
  }

  // Confirmar un mensaje pendiente cuando el servidor lo confirma
  // Retorna true si se confirmó un mensaje, false si no se encontró
  bool confirmPendingMessage(
    String channel,
    String message,
    DateTime timestamp,
  ) {
    // Para canales normales, normalizar con '#'. Para queries privados (nick),
    // usar el nombre tal cual en minúsculas.
    final normalized = channel.startsWith('#')
        ? _normalizeChannelName(channel)
        : channel.trim().toLowerCase();
    if (!channels.containsKey(normalized)) {
      // debugLog('⚠️  [IRCService] Canal no existe para confirmar: $normalized');
      return false;
    }

    final channelObj = channels[normalized]!;
    // Buscar mensaje pendiente que coincida (mismo canal, mismo mensaje, mismo timestamp aproximado)
    // Comparar mensajes normalizados (sin espacios extra, case-insensitive para el contenido)
    final normalizedReceivedMessage = message.trim();
    // debugLog('🔍 [IRCService] Buscando mensaje pendiente para confirmar: "$normalizedReceivedMessage" en canal $normalized');
    // debugLog('🔍 [IRCService] Total mensajes en canal: ${channelObj.messages.length}');

    // Buscar desde el final (más reciente) hacia el principio para encontrar el mensaje más reciente primero
    for (var i = channelObj.messages.length - 1; i >= 0; i--) {
      final msg = channelObj.messages[i];
      if (msg.isPending && msg.channel == normalized) {
        // Comparar mensajes normalizados (trim y comparar)
        final normalizedPendingMessage = msg.message.trim();
        // debugLog('🔍 [IRCService] Comparando pendiente[$i]: "$normalizedPendingMessage" con recibido: "$normalizedReceivedMessage"');
        // También verificar si el mensaje recibido contiene el mensaje pendiente o viceversa
        // (por si hay diferencias menores en el formato)
        if (normalizedPendingMessage == normalizedReceivedMessage ||
            _multilineMessagesMatch(
              normalizedPendingMessage,
              normalizedReceivedMessage,
            )) {
          // Confirmar el mensaje (marcar como no pendiente, preservando todos los campos)
          final confirmedMsg = msg.copyWith(
            isPending: false,
            pendingId: null,
            // Preservar replyToMessageId y otros campos
          );
          channelObj.messages[i] = confirmedMsg;
          // debugLog('✅ [IRCService] Mensaje confirmado en índice $i: ${msg.pendingId}');
          // Notificar a los listeners de mensajes para actualizar la UI
          _notifyMessageListeners(confirmedMsg);
          // También notificar a los listeners de lista de usuarios para forzar actualización del provider
          _notifyUserListListeners(normalized);
          return true;
        }
      }
    }
    // debugLog('⚠️  [IRCService] No se encontró mensaje pendiente para confirmar: "$normalizedReceivedMessage" en canal $normalized');
    return false;
  }

  // Enviar mensaje privado a un servicio IRC (NickServ, ChanServ, HostServ, etc.)
  void sendServiceMessage(String service, String message) {
    // Los servicios IRC no usan #, solo el nombre del servicio
    final serviceName = service.trim();
    _sendCommand('PRIVMSG $serviceName :$message');
    // debugLog('📤 [IRCService] Enviando mensaje a servicio $serviceName: $message');
  }

  // Identificar el nick con el bot "nick" usando IDENTIFY
  void identifyNick(String password) {
    if (_nickname == null || _nickname!.isEmpty) {
      // debugLog('⚠️ [IRCService] No hay nick para identificar');
      return;
    }

    final trimmedPassword = password.trim();
    if (trimmedPassword.isEmpty) {
      // debugLog('⚠️ [IRCService] La contraseña está vacía');
      return;
    }

    // Enviar IDENTIFY al bot "nick" (equivale a /msg nick identify password)
    // Formato: PRIVMSG nick :identify password (el bot identifica por el nick actual)
    final command = 'PRIVMSG nick :identify $trimmedPassword';
    _sessionIdentifyPassword = trimmedPassword;
    // debugLog('🔐 [IRCService] Identificando nick ${_nickname} con bot "nick"');
    // debugLog('🔐 [IRCService] Comando completo: $command');
    _sendCommand(command);
  }

  // Verificar el status de un nick (STATUS nick)
  // Retorna un Completer que se completa con el status (3 = registrado)
  Completer<int?> checkNickStatus(String nick) {
    final completer = Completer<int?>();
    final normalizedNick = nick.trim().toLowerCase();

    // Guardar el completer para que el parser de NOTICE lo pueda completar
    _statusCheckCompleters[normalizedNick] = completer;

    // Enviar comando STATUS al bot "nick" (no "NickServ")
    // Formato: PRIVMSG nick :STATUS nick
    _sendCommand('PRIVMSG nick :STATUS $nick');
    // debugLog('📋 [IRCService] Verificando status del nick: $nick');
    // debugLog('📋 [IRCService] Comando enviado: PRIVMSG nick :STATUS $nick');

    // Timeout después de 10 segundos (aumentado para dar más tiempo al servidor)
    Timer(const Duration(seconds: 10), () {
      // Verificar si el completer todavía existe y no está completado
      final existingCompleter = _statusCheckCompleters[normalizedNick];
      if (existingCompleter != null &&
          existingCompleter == completer &&
          !completer.isCompleted) {
        // debugLog('⏱️  [IRCService] Timeout verificando status del nick: $nick');
        _statusCheckCompleters.remove(normalizedNick);
        completer.complete(null);
      } else if (completer.isCompleted) {
        // debugLog('✅ [IRCService] Status ya recibido para nick: $nick (timeout ignorado)');
      }
    });

    return completer;
  }

  // Enviar mensaje privado a un nick (query)
  void sendWhois(String nick) {
    _sendCommand('WHOIS $nick');
  }

  // Comandos de información
  void sendWho(String channel) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('WHO $normalized');
    // debugLog('👤 [IRCService] Solicitando información de usuarios en $normalized');
  }

  void sendList([String? pattern]) {
    if (pattern != null && pattern.isNotEmpty) {
      _sendCommand('LIST $pattern');
    } else {
      _sendCommand('LIST');
    }
    // debugLog('📋 [IRCService] Solicitando lista de canales${pattern != null ? " (patrón: $pattern)" : ""}');
  }

  void sendNames(String channel) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('NAMES $normalized');
    debugLog('👥 [IRCService] Solicitando lista de usuarios de $normalized');
  }

  // Comandos de gestión
  String? _defaultAwayMessage; // Mensaje de away por defecto

  void setDefaultAwayMessage(String? message) {
    _defaultAwayMessage = message;
  }

  String? getDefaultAwayMessage() {
    return _defaultAwayMessage;
  }

  void sendAway([String? message]) {
    // Determinar el mensaje final a usar
    String? finalMessage;
    bool shouldSetAway = true;

    if (message == null) {
      // Quitar away explícitamente
      shouldSetAway = false;
      finalMessage = null;
      _sendCommand('AWAY');
      // debugLog('✅ [IRCService] Quitando modo away');
    } else if (message.isEmpty &&
        _defaultAwayMessage != null &&
        _defaultAwayMessage!.isNotEmpty) {
      // Mensaje vacío pero hay mensaje por defecto, usar el por defecto
      finalMessage = _defaultAwayMessage;
      _sendCommand('AWAY :$_defaultAwayMessage');
      // debugLog('🚶 [IRCService] Estableciendo mensaje de ausencia (por defecto): $_defaultAwayMessage');
    } else if (message.isNotEmpty) {
      // Usar el mensaje proporcionado
      finalMessage = message;
      _sendCommand('AWAY :$message');
      // debugLog('🚶 [IRCService] Estableciendo mensaje de ausencia: $message');
    } else {
      // Mensaje vacío y no hay mensaje por defecto, quitar away
      shouldSetAway = false;
      finalMessage = null;
      _sendCommand('AWAY');
      // debugLog('✅ [IRCService] Quitando modo away (sin mensaje)');
    }

    // Actualizar estado local inmediatamente para feedback instantáneo
    _notifyAwayStatusListeners(shouldSetAway, finalMessage);

    // También actualizar el caché de whois para que el avatar muestre el indicador
    if (_nickname != null) {
      final nickLower = _nickname!.toLowerCase();
      final cachedInfo = _whoisCache[nickLower];
      if (cachedInfo != null) {
        final updatedInfo = cachedInfo.copyWith(
          isAway: shouldSetAway,
          awayMessage: finalMessage,
        );
        _whoisCache[nickLower] = updatedInfo;
        _notifyWhoisListeners(updatedInfo);
      } else {
        // Crear nueva entrada si no existe
        final newInfo = WhoisInfo(
          nick: _nickname!,
          isAway: shouldSetAway,
          awayMessage: finalMessage,
        );
        _whoisCache[nickLower] = newInfo;
        _notifyWhoisListeners(newInfo);
      }
    }
  }

  void sendBack() {
    _sendCommand('AWAY');
    // debugLog('✅ [IRCService] Volviendo de ausencia');
  }

  // Listeners para cambios de estado de away
  void addAwayStatusListener(Function(bool, String?) listener) {
    _awayStatusListeners.add(listener);
  }

  void removeAwayStatusListener(Function(bool, String?) listener) {
    _awayStatusListeners.remove(listener);
  }

  void _notifyAwayStatusListeners(bool isAway, String? awayMessage) {
    for (var listener in _awayStatusListeners) {
      listener(isAway, awayMessage);
    }
  }

  void sendMe(String channel, String action) {
    if (!_hasActiveConnection) {
      debugLog('⚠️ [IRCService] No se puede enviar /me: conexión no activa');
      return;
    }
    // Acciones hacia usuarios privados (query, sin #) van por PRIVMSG al nick.
    // _normalizeChannelName añade un '#' que rompería la entrega a un usuario.
    if (!channel.startsWith('#')) {
      sendPrivateAction(channel, action);
      return;
    }

    final normalized = _normalizeChannelName(channel);

    // Añadir el mensaje localmente primero
    if (channels.containsKey(normalized)) {
      final msg = IRCMessage(
        nick: _nickname ?? 'You',
        channel: normalized,
        message: action,
        timestamp: DateTime.now(),
        isAction: true,
        messageId: IRCMessage.generateMessageId(),
      );
      channels[normalized]!.addMessage(msg);
      _notifyMessageListeners(msg);
    }

    // Enviar el comando ACTION como PRIVMSG al canal (estándar IRC)
    final command = 'PRIVMSG $normalized :\x01ACTION $action\x01';
    debugLog(
      '🎭 [IRCService] Enviando acción /me como PRIVMSG en $normalized: $action',
    );
    _sendCommand(command);
  }

  /// Enviar CTCP ACTION a un usuario privado
  void sendPrivateAction(String nick, String action) {
    if (!_hasActiveConnection) return;
    final normalizedNick = nick.trim();
    if (normalizedNick.isEmpty) return;

    // Enviar ACTION como PRIVMSG al nick (CTCP estándar)
    final command = 'PRIVMSG $normalizedNick :\x01ACTION $action\x01';
    debugLog(
      '🎭 [IRCService] Enviando acción privada a $normalizedNick: $action',
    );
    _sendCommand(command);

    // Añadir mensaje localmente al query channel
    final queryChannel = normalizedNick.toLowerCase();
    if (!channels.containsKey(queryChannel)) {
      channels[queryChannel] = IRCChannel(name: queryChannel);
    }
    _recentPrivateSends[queryChannel] = DateTime.now();
    final msg = IRCMessage(
      nick: _nickname ?? 'You',
      channel: queryChannel,
      message: action,
      timestamp: DateTime.now(),
      isAction: true,
      messageId: IRCMessage.generateMessageId(),
    );
    channels[queryChannel]!.addMessage(msg);
    _notifyMessageListeners(msg);
  }

  void sendTyping(String target) {
    if (!_hasActiveConnection) return;
    final normalized = _normalizeChannelName(target);
    _sendCommand('PRIVMSG $normalized :\x01TYPING\x01');
  }

  void sendTypingStop(String target) {
    if (!_hasActiveConnection) return;
    final normalized = _normalizeChannelName(target);
    _sendCommand('PRIVMSG $normalized :\x01TYPING 0\x01');
  }

  void sendPoke(String nick, {String? channel}) {
    if (!_hasActiveConnection) return;
    final normalizedNick = nick.trim();
    if (normalizedNick.isEmpty) return;
    final currentChannel = channel ?? _currentChannel;
    if (currentChannel != null && currentChannel.startsWith('#')) {
      sendMe(currentChannel, '\u{1F44A} $normalizedNick');
    } else {
      sendMe(normalizedNick, '\u{1F44A}');
    }
  }

  void addPokeListener(void Function(String nick) listener) {
    _pokeListeners.add(listener);
  }

  void removePokeListener(void Function(String nick) listener) {
    _pokeListeners.remove(listener);
  }

  void _notifyPokeListeners(String nick) {
    for (var listener in _pokeListeners) {
      listener(nick);
    }
  }

  void addKissListener(void Function(String nick) listener) {
    _kissListeners.add(listener);
  }

  void removeKissListener(void Function(String nick) listener) {
    _kissListeners.remove(listener);
  }

  void _notifyKissListeners(String nick) {
    for (var listener in _kissListeners) {
      listener(nick);
    }
  }

  void addActionListener(void Function(String action, String fromNick) listener) {
    _actionListeners.add(listener);
  }

  void removeActionListener(void Function(String action, String fromNick) listener) {
    _actionListeners.remove(listener);
  }

  void _notifyActionListeners(String action, String fromNick) {
    for (var listener in _actionListeners) {
      listener(action, fromNick);
    }
  }

  /// Enviar acción interactiva a un usuario (via ACTION al canal)
  void sendActionToUser(String channel, String emoji, String target) {
    if (!_hasActiveConnection) return;
    // En un query privado (canal sin '#') el destinatario ya es el nick del
    // canal: la acción se envía sin repetir el nombre de destino.
    final isPrivateQuery = !channel.startsWith('#');
    final actionText = isPrivateQuery ? emoji : '$emoji $target';
    sendMe(channel, actionText);
  }

  /// Enviar acción masiva a todos los canales
  void sendMassiveAction(String emoji) {
    if (!_hasActiveConnection) return;
    for (final channelEntry in channels.entries) {
      final channelName = channelEntry.key;
      if (channelName.startsWith('#')) {
        sendMe(channelName, emoji);
      }
    }
  }

  void addTypingListener(
      void Function(String channel, String nick, bool isTyping) listener) {
    _typingListeners.add(listener);
  }

  void removeTypingListener(
      void Function(String channel, String nick, bool isTyping) listener) {
    _typingListeners.remove(listener);
  }

  void _notifyTypingListeners(String channel, String nick, bool isTyping) {
    for (var listener in _typingListeners) {
      listener(channel, nick, isTyping);
    }
  }

  void sendNotice(String target, String message) {
    _sendCommand('NOTICE $target :$message');
    // debugLog('📢 [IRCService] Enviando NOTICE a $target: $message');
  }

  void sendPrivateNotice(String nick, String message, {int delaySeconds = 0}) {
    final normalizedNick = nick.trim();
    if (normalizedNick.isEmpty) return;

    final queryChannel = normalizedNick.toLowerCase();
    if (!channels.containsKey(queryChannel)) {
      channels[queryChannel] = IRCChannel(name: queryChannel);
    }

    _sendWireNotice(normalizedNick, message);

    final msg = IRCMessage(
      nick: _nickname ?? 'You',
      channel: queryChannel,
      message: message,
      timestamp: DateTime.now(),
      isPending: false,
      messageId: IRCMessage.generateMessageId(),
    );
    channels[queryChannel]!.addMessage(msg);
    _notifyMessageListeners(msg);
  }

  // Comandos de moderación
  void kickUser(String channel, String nick, [String? reason]) {
    final normalized = _normalizeChannelName(channel);
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('KICK $normalized $nick :$reason');
    } else {
      _sendCommand('KICK $normalized $nick');
    }
    // debugLog('👢 [IRCService] Expulsando $nick de $normalized${reason != null ? " (razón: $reason)" : ""}');

    // Actualizar la lista de usuarios inmediatamente (optimización)
    // El servidor enviará el evento KICK que también actualizará la lista
    if (channels.containsKey(normalized)) {
      channels[normalized]!.removeUser(nick);
      _notifyUserListListeners(normalized);
    }
  }

  void banUser(String channel, String nick, [String? reason]) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('MODE $normalized +b $nick');
    // debugLog('🚫 [IRCService] Baneando $nick en $normalized');
  }

  void unbanUser(String channel, String nick) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('MODE $normalized -b $nick');
    // debugLog('✅ [IRCService] Desbaneando $nick en $normalized');
  }

  void setChannelMode(String channel, String modes, [String? target]) {
    final normalized = _normalizeChannelName(channel);
    if (target != null && target.isNotEmpty) {
      _sendCommand('MODE $normalized $modes $target');
    } else {
      _sendCommand('MODE $normalized $modes');
    }
    // debugLog('⚙️  [IRCService] Cambiando modo de $normalized: $modes${target != null ? " $target" : ""}');
  }

  // Solicitar los modos actuales del canal (respuesta: numerico 324)
  void requestChannelModes(String channel) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('MODE $normalized');
  }

  // Solicitar la lista de baneados del canal (respuesta: numericos 367/368)
  void requestBanList(String channel) {
    final normalized = _normalizeChannelName(channel);
    channels[normalized]?.clearBans();
    _notifyUserListListeners(normalized);
    _sendCommand('MODE $normalized +b');
  }

  // Activar/desactivar un modo simple de canal (+t, +m, +n, +i, +s, ...)
  void toggleChannelMode(String channel, String mode, bool enable) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('MODE $normalized ${enable ? '+' : '-'}$mode');
  }

  // Establecer/quitar la clave del canal (modo +k). Si key es null o vacio,
  // se quita la clave. UnrealIRCd exige la clave antigua en el -k, por eso se
  // envía la clave guardada localmente cuando la tenemos.
  void setChannelKey(String channel, String? key) {
    final normalized = _normalizeChannelName(channel);
    if (key == null || key.isEmpty) {
      final currentKey = channels[normalized]?.key;
      if (currentKey != null && currentKey.isNotEmpty) {
        _sendCommand('MODE $normalized -k $currentKey');
      } else {
        _sendCommand('MODE $normalized -k');
      }
      channels[normalized]?.key = null;
    } else {
      // Guardar la clave localmente de forma optimista: el echo del servidor
      // oculta la clave (MODE #chan +k), así que no llegaría por los numerics.
      channels[normalized]?.key = key;
      _sendCommand('MODE $normalized +k $key');
    }
  }

  // Establecer/quitar el limite de usuarios (modo +l). Si limit es null o <= 0,
  // se quita el limite (-l).
  void setChannelLimit(String channel, int? limit) {
    final normalized = _normalizeChannelName(channel);
    if (limit == null || limit <= 0) {
      channels[normalized]?.limit = null;
      _sendCommand('MODE $normalized -l');
    } else {
      channels[normalized]?.limit = limit;
      _sendCommand('MODE $normalized +l $limit');
    }
  }

  // Desbanear una mascara concreta de la lista de bans
  void unbanMask(String channel, String mask) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('MODE $normalized -b $mask');
  }

  // Aplica una cadena de modos (p. ej. "+ntmkl") a un objeto de canal.
  // Gestiona tanto modos de usuario (o/v/h/a/q -> prefijos @/+/%/) como modos
  // de canal con/sin parámetro (k -> clave, l -> límite). Devuelve true si
  // hubo cambios y los listeners deben notificarse.
  static bool _applyChannelModeString(
    IRCChannel channelObj,
    String modeStr,
    List<String> params,
  ) {
    // Mapeo modo IRC -> prefijo UI: v=+, o=@, h=%, a=!, q=&
    const addMap = {'v': '+', 'o': '@', 'h': '%', 'a': '!', 'q': '&'};
    const removeMap = {'v': '+', 'o': '@', 'h': '%', 'a': '!', 'q': '&'};
    // Modos que usan un nick como parámetro
    const nickTargetModes = {'v', 'o', 'h', 'a', 'q', 'b', 'e', 'I'};
    // Modos de canal que consumen un parámetro no-nick
    const channelParamModes = {'k', 'l', 'j', 'f', 'L'};

    bool adding = true;
    int paramIndex = 0;
    bool changed = false;

    for (int i = 0; i < modeStr.length; i++) {
      final c = modeStr[i];
      if (c == '+') {
        adding = true;
        continue;
      }
      if (c == '-') {
        adding = false;
        continue;
      }

      if (nickTargetModes.contains(c)) {
        if (c == 'o' || c == 'v' || c == 'h' || c == 'a' || c == 'q') {
          if (paramIndex >= params.length) continue;
          final targetNick = params[paramIndex].replaceFirst(':', '');
          paramIndex++;
          final nickLower = targetNick.toLowerCase();
          String? existingKey;
          for (var u in channelObj.users) {
            if (u.toLowerCase() == nickLower) {
              existingKey = u;
              break;
            }
          }
          if (existingKey == null) continue;
          final prefix = adding ? addMap[c] : removeMap[c];
          if (prefix == null) continue;
          if (adding) {
            channelObj.addUser(existingKey, mode: prefix);
          } else {
            final current = channelObj.getUserMode(existingKey);
            if (current == prefix) {
              String? keyToRemove;
              for (var k in channelObj.userModes.keys) {
                if (k.toLowerCase() == nickLower) {
                  keyToRemove = k;
                  break;
                }
              }
              if (keyToRemove != null) {
                channelObj.userModes.remove(keyToRemove);
              }
            }
          }
          changed = true;
        }
        // Los modos +b/+e/+I (bans/excepciones) no se gestionan aquí;
        // la lista de bans llega por los numericos 367.
        continue;
      }

      if (channelParamModes.contains(c)) {
        if (paramIndex < params.length) {
          final param = params[paramIndex].replaceFirst(':', '');
          paramIndex++;
          if (c == 'k') {
            channelObj.key = adding ? param : null;
          } else if (c == 'l') {
            channelObj.limit = adding ? int.tryParse(param) : null;
          }
        }
        if (adding) {
          channelObj.channelModes.add(c);
        } else {
          channelObj.channelModes.remove(c);
        }
        changed = true;
        continue;
      }

      if (adding) {
        if (channelObj.channelModes.add(c)) changed = true;
      } else {
        if (channelObj.channelModes.remove(c)) changed = true;
      }
    }

    return changed;
  }

  void setChannelTopic(String channel, String topic) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('TOPIC $normalized :$topic');
    // debugLog('📌 [IRCService] Cambiando topic de $normalized: $topic');
  }

  // ========== COMANDOS DE IRCOP (UnrealIRCd) ==========

  // OPER: Autenticarse como operador IRC
  void oper(String nick, String password) {
    _sendCommand('OPER $nick $password');
    // debugLog('🔐 [IRCService] Intentando autenticarse como operador: $nick');
  }

  // KILL: Desconectar a un usuario del servidor
  void killUser(String nick, [String? reason]) {
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('KILL $nick :$reason');
    } else {
      _sendCommand('KILL $nick');
    }
    // debugLog('💀 [IRCService] KILL: Desconectando $nick${reason != null ? " (razón: $reason)" : ""}');
  }

  // GLINE: Prohibir a un usuario o rango de IPs conectarse al servidor
  void glineUser(String userhost, [String? duration, String? reason]) {
    String command = 'GLINE $userhost';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // debugLog('🚫 [IRCService] GLINE: $userhost${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // KLINE: Similar a GLINE pero solo para el servidor local
  void klineUser(String userhost, [String? duration, String? reason]) {
    String command = 'KLINE $userhost';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // debugLog('🚫 [IRCService] KLINE: $userhost${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // ZLINE: Banear una IP específica
  void zlineIP(String ip, [String? duration, String? reason]) {
    String command = 'ZLINE $ip';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // debugLog('🚫 [IRCService] ZLINE: $ip${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // SHUN: Silenciar a un usuario
  void shunUser(String userhost, [String? duration, String? reason]) {
    String command = 'SHUN $userhost';
    if (duration != null && duration.isNotEmpty) {
      command += ' $duration';
    }
    if (reason != null && reason.isNotEmpty) {
      command += ' :$reason';
    }
    _sendCommand(command);
    // debugLog('🔇 [IRCService] SHUN: $userhost${duration != null ? " por $duration" : ""}${reason != null ? " (razón: $reason)" : ""}');
  }

  // SAJOIN: Forzar a un usuario a unirse a un canal
  void sajoinUser(String nick, String channel) {
    final normalized = _normalizeChannelName(channel);
    _sendCommand('SAJOIN $nick $normalized');
    // debugLog('➡️ [IRCService] SAJOIN: Forzando a $nick a unirse a $normalized');
  }

  // SAPART: Forzar a un usuario a salir de un canal
  void sapartUser(String nick, String channel) {
    final normalized = _normalizeChannelName(channel);
    sendPrivateMessage('ircop', 'SAPART $nick $normalized');
    // debugLog('⬅️ [IRCService] SAPART: Forzando a $nick a salir de $normalized');
  }

  // SAMODE: Cambiar los modos de un canal sin ser operador
  void samodeChannel(String channel, String modes, [String? target]) {
    final normalized = _normalizeChannelName(channel);
    if (target != null && target.isNotEmpty) {
      sendPrivateMessage('ircop', 'SAMODE $normalized $modes $target');
    } else {
      sendPrivateMessage('ircop', 'SAMODE $normalized $modes');
    }
    // debugLog('⚙️ [IRCService] SAMODE: Cambiando modo de $normalized: $modes${target != null ? " $target" : ""}');
  }

  // SVSNICK: Cambiar el nick de un usuario
  void svsnickUser(String nick, String newNick) {
    sendPrivateMessage('ircop', 'SVSNICK $nick $newNick');
    // debugLog('👤 [IRCService] SVSNICK: Cambiando nick de $nick a $newNick');
  }

  // SAPRIVMSG: Enviar mensaje privado como servicio
  void saprivmsgUser(String nick, String message) {
    sendPrivateMessage('ircop', 'SAPRIVMSG $nick :$message');
    // debugLog('📨 [IRCService] SAPRIVMSG: Enviando mensaje a $nick: $message');
  }

  // SQUIT: Desconectar un servidor de la red
  void squitServer(String server, [String? reason]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'SQUIT';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'SQUIT') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de SQUIT (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('SQUIT $server :$reason');
    } else {
      _sendCommand('SQUIT $server');
    }
    // debugLog('🔌 [IRCService] SQUIT: Desconectando servidor $server${reason != null ? " (razón: $reason)" : ""}');
  }

  // REHASH: Recargar la configuración del servidor
  void rehashServer() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'REHASH';
    // Cancelar timer anterior si existe
    _ircopCommandTimer?.cancel();
    // Timer para finalizar la captura después de 3 segundos
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'REHASH') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de REHASH (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('REHASH');
    // debugLog('🔄 [IRCService] REHASH: Recargando configuración del servidor');
  }

  // RESTART: Reiniciar el servidor
  void restartServer([String? reason]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'RESTART';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'RESTART') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de RESTART (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('RESTART :$reason');
    } else {
      _sendCommand('RESTART');
    }
    // debugLog('🔄 [IRCService] RESTART: Reiniciando servidor${reason != null ? " (razón: $reason)" : ""}');
  }

  // DIE: Apagar el servidor
  void dieServer([String? reason]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'DIE';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'DIE') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de DIE (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    if (reason != null && reason.isNotEmpty) {
      _sendCommand('DIE :$reason');
    } else {
      _sendCommand('DIE');
    }
    // debugLog('💀 [IRCService] DIE: Apagando servidor${reason != null ? " (razón: $reason)" : ""}');
  }

  // CONNECT: Conectar un servidor a la red
  void connectServer(String server, int port, [String? password]) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'CONNECT';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 5), () {
      if (_currentIRCOpCommand == 'CONNECT') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de CONNECT (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    String command = 'CONNECT $server $port';
    if (password != null && password.isNotEmpty) {
      command += ' $password';
    }
    _sendCommand(command);
    // debugLog('🔗 [IRCService] CONNECT: Conectando servidor $server:$port');
  }

  // DCCDENY: Denegar DCC de un usuario
  void dccdenyUser(String nick) {
    _sendCommand('DCCDENY $nick');
    // debugLog('🚫 [IRCService] DCCDENY: Denegando DCC de $nick');
  }

  // UNDCCDENY: Permitir DCC de un usuario
  void undccdenyUser(String nick) {
    _sendCommand('UNDCCDENY $nick');
    // debugLog('✅ [IRCService] UNDCCDENY: Permitiendo DCC de $nick');
  }

  // TSCTL: Comandos de control de timestamp
  void tsctlCommand(String command) {
    _sendCommand('TSCTL $command');
    // debugLog('⏰ [IRCService] TSCTL: $command');
  }

  // MKPASSWD: Generar hash de contraseña
  void mkpasswd(String password) {
    _sendCommand('MKPASSWD $password');
    // debugLog('🔐 [IRCService] MKPASSWD: Generando hash de contraseña');
  }

  // STATS: Obtener estadísticas del servidor
  void statsCommand(String type) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'STATS';
    _sendCommand('STATS $type');
    // debugLog('📊 [IRCService] STATS: Solicitando estadísticas tipo $type');
  }

  // TRACE: Rastrear la ruta de un usuario o servidor
  void traceTarget(String target) {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'TRACE';
    _sendCommand('TRACE $target');
    // debugLog('🔍 [IRCService] TRACE: Rastreando $target');
  }

  // LINKS: Listar servidores conectados
  void linksCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'LINKS';
    _sendCommand('LINKS');
    // debugLog('🔗 [IRCService] LINKS: Solicitando lista de servidores');
  }

  // MAP: Mapa de la red
  void mapCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'MAP';
    _sendCommand('MAP');
    // debugLog('🗺️ [IRCService] MAP: Solicitando mapa de la red');
  }

  // MOTD: Mensaje del día
  void motdCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'MOTD';
    _sendCommand('MOTD');
    // debugLog('📝 [IRCService] MOTD: Solicitando mensaje del día');
  }

  // VERSION: Versión del servidor
  void versionCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'VERSION';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'VERSION') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de VERSION (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('VERSION');
    // debugLog('ℹ️ [IRCService] VERSION: Solicitando versión del servidor');
  }

  // ADMIN: Información de administración
  void adminCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'ADMIN';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'ADMIN') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de ADMIN (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('ADMIN');
    // debugLog('👨‍💼 [IRCService] ADMIN: Solicitando información de administración');
  }

  // LUSERS: Estadísticas de usuarios
  void lusersCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'LUSERS';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'LUSERS') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de LUSERS (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('LUSERS');
    // debugLog('👥 [IRCService] LUSERS: Solicitando estadísticas de usuarios');
  }

  // TIME: Hora del servidor
  void timeCommand() {
    _ircopCommandResults.clear();
    _currentIRCOpCommand = 'TIME';
    _ircopCommandTimer?.cancel();
    _ircopCommandTimer = Timer(const Duration(seconds: 3), () {
      if (_currentIRCOpCommand == 'TIME') {
        _notifyIRCOpCommandListeners(_ircopCommandResults);
        // debugLog('📋 [IRCOp] Fin de TIME (${_ircopCommandResults.length} líneas)');
        _ircopCommandResults.clear();
        _currentIRCOpCommand = null;
        _ircopCommandTimer = null;
      }
    });
    _sendCommand('TIME');
    // debugLog('🕐 [IRCService] TIME: Solicitando hora del servidor');
  }

  // WALLOPS: Mensaje a todos los operadores
  void wallops(String message) {
    sendPrivateMessage('ircop', 'WALLOPS :$message');
    // debugLog('📢 [IRCService] WALLOPS: $message');
  }

  // GLOBOPS: Mensaje global a todos los operadores
  void globops(String message) {
    sendPrivateMessage('ircop', 'GLOBOPS :$message');
    // debugLog('🌍 [IRCService] GLOBOPS: $message');
  }

  // ADMIND: Mensaje a administradores
  void admind(String message) {
    sendPrivateMessage('ircop', 'ADMIND :$message');
    // debugLog('👨‍💼 [IRCService] ADMIND: $message');
  }

  // LOCOPS: Mensaje a operadores locales
  void locops(String message) {
    sendPrivateMessage('ircop', 'LOCOPS :$message');
    // debugLog('🏠 [IRCService] LOCOPS: $message');
  }

  void sendIgnore(String nick) {
    final normalizedNick = nick.trim().toLowerCase();
    if (normalizedNick.isEmpty) return;

    // Añadir a la lista local de ignorados
    _ignoredUsers.add(normalizedNick);
    // debugLog('🚫 [IRCService] Usuario añadido a lista de ignorados: $normalizedNick');

    _sendCommand(
      'MODE $nick +b',
    ); // Ignorar usando modo ban (depende del servidor IRC)
    // Alternativa: algunos servidores usan /ignore directamente
    _sendCommand('IGNORE $nick');
  }

  void sendUnignore(String nick) {
    final normalizedNick = nick.trim().toLowerCase();
    if (normalizedNick.isEmpty) return;

    // Remover de la lista local de ignorados
    _ignoredUsers.remove(normalizedNick);
    // debugLog('✅ [IRCService] Usuario removido de lista de ignorados: $normalizedNick');

    _sendCommand('MODE $nick -b'); // Designorar usando modo ban
    // Alternativa: algunos servidores usan /unignore directamente
    _sendCommand('UNIGNORE $nick');
  }

  bool isUserIgnored(String nick) {
    return _ignoredUsers.contains(nick.toLowerCase());
  }

  bool _ignoreAllPrivates = false;

  void setIgnoreAllPrivates(bool value) {
    _ignoreAllPrivates = value;
    debugLog('🚫 [IRCService] Ignorar todos los privados: $value');
  }

  bool get ignoreAllPrivates => _ignoreAllPrivates;

  // Detectar si un nick es un bot basándose en el host y el nick
  bool _isBotByHostOrNick(String nick, String? host) {
    if (isBotNick(nick)) return true;

    // Verificar por host
    if (host != null) {
      final hostLower = host.toLowerCase();
      if (hostLower == 'robot.globalchat.org' ||
          hostLower.endsWith('.robot.globalchat.org') ||
          (hostLower.startsWith('robot.') &&
              hostLower.contains('globalchat.org') &&
              !hostLower.contains('netadmin') &&
              !hostLower.contains('admin'))) {
        return true;
      }
    }
    return false;
  }

  /// Verifica si un nick corresponde a un bot (solo por nick, sin host).
  bool isBotNick(String nick) {
    final nickLower = nick.toLowerCase().trim();

    final officialBots = <String>{
      'globalchat', 'orion', 'seenallbot', 'stats', 'youtubebot',
      'chan', 'nick', 'memo', 'ircop', 'global', 'ipvirtual',
      'botita', 'z', 'futbol',
      'nickserv', 'chanserv', 'memoserv', 'botserv', 'hostserv',
      'statserv', 'robot', 'bot',
    };

    return officialBots.contains(nickLower) ||
        nickLower.endsWith('bot') ||
        nickLower.startsWith('radio');
  }

  // Enviar comando a ChanServ (Anope)
  void sendChanServCommand(String channel, String command, [String? params]) {
    final normalized = _normalizeChannelName(channel);
    String fullCommand = command;
    if (params != null && params.isNotEmpty) {
      fullCommand = '$command $normalized $params';
    } else {
      fullCommand = '$command $normalized';
    }
    sendPrivateMessage('ChanServ', fullCommand);
    // debugLog('🔧 [IRCService] Comando ChanServ enviado: $fullCommand');
  }

  bool sendPrivateMessage(String nick, String message, {int delaySeconds = 0}) {
    if (!_hasActiveConnection || !_isRegistered || _isReconnecting) {
      debugLog(
        '⚠️ [IRCService] sendPrivateMessage abortado: conexión no lista',
      );
      return false;
    }

    final normalizedNick = nick.trim();
    if (normalizedNick.isEmpty) return false;

    final queryChannel = normalizedNick.toLowerCase();
    if (!channels.containsKey(queryChannel)) {
      channels[queryChannel] = IRCChannel(name: queryChannel);
    }
    _recentPrivateSends[queryChannel] = DateTime.now();

    // Enviar por la red PRIMERO; solo agregar localmente si el envío fue exitoso
    final sent = _sendWirePrivmsg(normalizedNick, message);
    if (!sent) {
      return false;
    }

    final msg = IRCMessage(
      nick: _nickname ?? 'You',
      channel: queryChannel,
      message: message,
      timestamp: DateTime.now(),
      isPending: false,
      messageId: IRCMessage.generateMessageId(),
    );
    channels[queryChannel]!.addMessage(msg);
    _notifyMessageListeners(msg);

    return true;
  }

  // Cambiar el nickname
  void changeNick(String newNick) {
    if (!_hasActiveConnection) {
      debugLog('⚠️ [IRCService] No se puede cambiar nick: conexión no activa');
      return;
    }

    final trimmedNick = newNick.trim();
    if (trimmedNick.isEmpty) {
      debugLog('⚠️  [IRCService] No se puede cambiar a un nick vacío');
      return;
    }

    if (trimmedNick == _nickname) {
      debugLog('ℹ️  [IRCService] Ya estás usando ese nick');
      return;
    }

    debugLog('🔄 [IRCService] Cambiando nick de "$_nickname" a "$trimmedNick"');
    _sessionNickname = trimmedNick;
    _sendCommand('NICK $trimmedNick');
    // El servidor confirmará el cambio con un mensaje NICK, entonces actualizaremos _nickname
    // cuando recibamos la confirmación del servidor
  }

  // Enviar acción /me a todos los canales donde estás presente
  void sendAme(String action) {
    if (!_hasActiveConnection) {
      debugLog('⚠️ [IRCService] No se puede enviar /ame: conexión no activa');
      return;
    }

    if (action.trim().isEmpty) {
      debugLog('⚠️ [IRCService] No se puede enviar /ame: acción vacía');
      return;
    }

    debugLog(
      '🎭 [IRCService] Enviando acción /ame como NOTICE a todos los canales: $action',
    );

    // Enviar a todos los canales donde estás presente
    for (final channelEntry in channels.entries) {
      final channelName = channelEntry.key;
      // Solo enviar a canales (que empiezan con #), no a queries privadas
      if (channelName.startsWith('#')) {
        final normalized = _normalizeChannelName(channelName);

        // Añadir el mensaje localmente primero
        if (channels.containsKey(normalized)) {
          final msg = IRCMessage(
            nick: _nickname ?? 'You',
            channel: normalized,
            message: action,
            timestamp: DateTime.now(),
            isAction: true,
            messageId: IRCMessage.generateMessageId(),
          );
          channels[normalized]!.addMessage(msg);
          _notifyMessageListeners(msg);
        }

        // Enviar el comando ACTION como PRIVMSG al servidor (estándar IRC)
        final command = 'PRIVMSG $normalized :\x01ACTION $action\x01';
        debugLog(
          '🎭 [IRCService] Enviando /ame como PRIVMSG a $normalized: $action',
        );
        _sendCommand(command);
      }
    }
  }

  void _sendCommand(String command) {
    if (_connection != null && _connection!.isConnected) {
      debugLog('🔍 [IRCService] ✅ Sending command: $command');
      // Agregar \r\n para compatibilidad IRC
      final ircCommand = command.endsWith('\r\n') ? command : '$command\r\n';
      try {
        _connection!.send(ircCommand);
      } catch (e) {
        debugLog('❌ [IRCService] Error enviando comando "$command": $e');
        _forceReconnect(reason: 'send_command_failed');
      }
    } else {
      debugLog(
        '🔍 [IRCService] ⚠️  Cannot send command "$command": connection is null or not connected',
      );
    }
  }

  /// Envía un comando IRC y devuelve si la conexión estaba activa al enviar.
  bool _trySendCommand(String command) {
    if (_connection == null || !_connection!.isConnected) {
      debugLog(
        '🔍 [IRCService] ⚠️  Cannot send command "$command": connection is null or not connected',
      );
      return false;
    }
    debugLog('🔍 [IRCService] ✅ Sending command: $command');
    final ircCommand = command.endsWith('\r\n') ? command : '$command\r\n';
    try {
      _connection!.send(ircCommand);
      return true;
    } catch (e) {
      debugLog('❌ [IRCService] Error enviando comando "$command": $e');
      _forceReconnect(reason: 'send_command_failed');
      return false;
    }
  }

  /// Enviar un comando IRC raw al servidor
  void sendRaw(String command) {
    _sendCommand(command);
  }

  // Método para agregar listeners de debug
  void addDebugLogListener(Function(String) listener) {
    _debugLogListeners.add(listener);
  }

  void removeDebugLogListener(Function(String) listener) {
    _debugLogListeners.remove(listener);
  }

  void _notifyDebugLog(String message) {
    for (var listener in _debugLogListeners) {
      try {
        listener(message);
      } catch (e) {
        // Ignorar errores en listeners
      }
    }
  }

  // Métodos para listeners de canales de ayuda
  void addHelpChannelJoinListener(Function(String) listener) {
    _helpChannelJoinListeners.add(listener);
  }

  void removeHelpChannelJoinListener(Function(String) listener) {
    _helpChannelJoinListeners.remove(listener);
  }

  void _notifyHelpChannelJoinListeners(String channel) {
    for (var listener in _helpChannelJoinListeners) {
      try {
        listener(channel);
      } catch (e) {
        debugLog('❌ [IRC] Error en listener de canal de ayuda: $e');
      }
    }
  }

  // Métodos para listeners de canal #werewolf
  void addWerewolfChannelJoinListener(Function(String) listener) {
    _werewolfChannelJoinListeners.add(listener);
  }

  void removeWerewolfChannelJoinListener(Function(String) listener) {
    _werewolfChannelJoinListeners.remove(listener);
  }

  void _notifyWerewolfChannelJoinListeners(String channel) {
    for (var listener in _werewolfChannelJoinListeners) {
      try {
        listener(channel);
      } catch (e) {
        debugLog('❌ [IRC] Error en listener de canal #werewolf: $e');
      }
    }
  }

  void _handleData(String rawData) {
    try {
      // Notificar a los listeners de debug
      _notifyDebugLog(rawData);
      _lastServerActivityAt = DateTime.now();

      final lines = rawData.split('\r\n');

      for (var line in lines) {
        if (line.isEmpty) continue;

        // Log especial para comandos JOIN, 353, 366, 332 (TOPIC), NICK
        if (line.contains(' JOIN ') ||
            line.contains(' 353 ') ||
            line.contains(' 366 ') ||
            line.contains(' 332 ') ||
            line.contains(' NICK ')) {
          // debugLog('🔍 [DEBUG] ⭐ Important IRC message: $line');
        }

        // Log específico para TOPIC
        if (line.contains(' 332 ')) {
          // debugLog('🔍 [DEBUG] 📌📌📌 RAW TOPIC MESSAGE RECEIVED: $line');
          // debugLog('🔍 [DEBUG] 📌📌📌 Full raw line length: ${line.length}');
          // debugLog('🔍 [DEBUG] 📌📌📌 Line bytes: ${line.codeUnits}');
        }

        // Log específico para NICK
        if (line.contains(' NICK ')) {
          // debugLog('🔄 [DEBUG] 🔄🔴 RAW NICK MESSAGE RECEIVED: $line');
        }

        _parseIRCMessage(line);
      }
    } catch (e, stack) {
      debugLog('❌ [IRCService] Error en _handleData: $e\n$stack');
    }
  }

  void _parseIRCMessage(String line) {
    // Manejar PING del servidor
    if (line.startsWith('PING')) {
      final pingToken = line.length > 5 ? line.substring(5).trim() : '';
      _sendCommand('PONG $pingToken');

      // Si el servidor nos envía PING, también podemos medir el lag
      // pero es mejor usar nuestro propio PING periódico
      return;
    }

    // Detectar PONG del servidor (respuesta a nuestro PING)
    // Formato: PONG :token o :server PONG :token
    if (line.contains(' PONG ') || line.startsWith('PONG')) {
      String? pongToken;
      // Intentar extraer el token del PONG
      if (line.startsWith('PONG')) {
        // Formato: PONG :token
        final parts = line.split(' ');
        if (parts.length > 1) {
          pongToken = parts[1].replaceFirst(':', '').trim();
        }
      } else {
        // Formato: :server PONG :token
        final pongMatch = RegExp(r'PONG\s+:?(.+)').firstMatch(line);
        if (pongMatch != null) {
          pongToken = pongMatch.group(1)?.trim();
        }
      }

      // Si es respuesta a nuestro PING, calcular el lag
      if (pongToken != null &&
          _lastPingSent != null &&
          _lastPingToken != null &&
          pongToken == _lastPingToken) {
        final lagMs = DateTime.now().difference(_lastPingSent!).inMilliseconds;
        _notifyLagListeners(lagMs);
        _lastServerActivityAt = DateTime.now();
        _lastPingSent = null;
        _lastPingToken = null;
        // debugLog('📊 [IRCService] Lag medido: ${lagMs}ms');
      }
      return;
    }

    // Parse `:nick!user@host COMMAND args`
    if (!line.startsWith(':')) return;

    try {
      final parts = line.split(' ');
      if (parts.length < 2) return;

      final source = parts[0].substring(1); // Remove ':'
      final command = parts[1];
      final args = parts.sublist(2);

      final nick = source.split('!')[0];
      // Extraer el host del source (formato: nick!user@host)
      String? host;
      if (source.contains('@')) {
        host = source.split('@').length > 1 ? source.split('@')[1] : null;
      }

      // Log todos los comandos numéricos (353, 366, etc.) para debug
      if (RegExp(r'^\d{3}$').hasMatch(command)) {
        // debugLog('🔍 [DEBUG] Received numeric command: $command (line: $line)');
        // Log específico para comandos whois
        if ([
          '311',
          '312',
          '313',
          '317',
          '318',
          '319',
          '301',
        ].contains(command)) {
          // debugLog('🔍 [WHOIS DEBUG] Command: $command, Args: $args');
        }
      }

      // Log si el mensaje contiene nuestro nickname
      if (_nickname != null && line.contains(_nickname!)) {
        // debugLog('🔍 [DEBUG] ⭐ Message contains our nickname "$_nickname": $line');
      }

      switch (command) {
        case '001': // Welcome
          // En el mensaje 001, el formato es: :server 001 nickname :Welcome message
          // El nickname está en args[0], no en el source (que es el nombre del servidor)
          String? confirmedNick;
          if (args.isNotEmpty) {
            confirmedNick = args[0];
            if (confirmedNick.startsWith(':')) {
              confirmedNick = confirmedNick.substring(1);
            }
            confirmedNick = confirmedNick.trim();
          } else {
            confirmedNick = _nickname; // Fallback al nick que enviamos
          }

          debugLog(
            '✅ [IRC] Welcome message received (001) - connected as $confirmedNick to $_currentHost',
          );
          debugLog('✅ [IRC] Usuario registrado correctamente, listo para JOIN');
          // debugLog('🔍 [DEBUG] ✅✅✅ User is now fully registered! Ready for JOIN commands ✅✅✅');
          _isRegistered = true; // Marcar que el usuario está registrado
          // Actualizar el nickname con el confirmado por el servidor (puede tener guion si fue rechazado)
          if (confirmedNick != null &&
              confirmedNick.isNotEmpty &&
              confirmedNick != _nickname) {
            _nickname = confirmedNick;
            // Notificar a los listeners del cambio de nick
            for (var listener in _nickChangeListeners) {
              try {
                listener(confirmedNick);
              } catch (e) {
                // Ignorar errores en listeners
              }
            }
          }
          if (!_connectionCompleter.isCompleted) {
            _connectionCompleter.complete();
          }

          // Autojoin a #globalchat SOLO UNA VEZ al inicio, después de recibir el 001
          // Solo si no fue cerrado manualmente y no se ha hecho antes
          const globalChatChannel = '#globalchat';
          final globalChatLower = globalChatChannel.toLowerCase();
          final wasManuallyClosed = _manuallyClosedChannels.contains(
            globalChatLower,
          );

          // Permitir desactivar el autojoin al canal oficial mediante configuración
          if (!_autoJoinOfficialGlobalChat) {
            debugLog(
              '🌐 [IRC] Autojoin a #globalchat desactivado por configuración (joinchanneloficial=false)',
            );
            break;
          }

          if (!_hasAutoJoinedGlobalChat &&
              !wasManuallyClosed &&
              _nickname != null) {
            // Verificar si ya estamos en #globalchat
            final globalChat = channels[globalChatChannel];
            final isInGlobalChat =
                globalChat != null &&
                globalChat.users.any(
                  (user) => user.toLowerCase() == _nickname!.toLowerCase(),
                );

            if (!isInGlobalChat) {
              _hasAutoJoinedGlobalChat = true; // Marcar como hecho
              // Esperar un poco antes de unirse para no saturar el servidor
              Future.delayed(const Duration(milliseconds: 300), () {
                // Verificar nuevamente antes de hacer JOIN
                final globalChatNow = channels[globalChatChannel];
                final stillNotInGlobalChat =
                    globalChatNow == null ||
                    (_nickname != null &&
                        !globalChatNow.users.any(
                          (user) =>
                              user.toLowerCase() == _nickname!.toLowerCase(),
                        ));

                // Verificar que no fue cerrado manualmente mientras esperábamos
                final stillManuallyClosed = _manuallyClosedChannels.contains(
                  globalChatLower,
                );

                if (_isConnected &&
                    _hasActiveConnection &&
                    stillNotInGlobalChat &&
                    _nickname != null &&
                    !stillManuallyClosed) {
                  debugLog(
                    '🌐 [IRC] ✅ Auto-uniéndose al canal oficial #globalchat (después de registro 001)',
                  );
                  _sendCommand('JOIN $globalChatChannel');
                  // Crear el canal en el mapa si no existe
                  if (!channels.containsKey(globalChatChannel)) {
                    channels[globalChatChannel] = IRCChannel(
                      name: globalChatChannel,
                    );
                  }
                } else if (stillManuallyClosed) {
                  debugLog(
                    '🌐 [IRC] ⚠️ #globalchat fue cerrado manualmente, no se volverá a abrir',
                  );
                }
              });
            } else {
              _hasAutoJoinedGlobalChat =
                  true; // Ya estamos dentro, marcar como hecho
              debugLog(
                '🌐 [IRC] ✅ Ya estamos en #globalchat, no es necesario autojoin',
              );
            }
          } else if (wasManuallyClosed) {
            debugLog(
              '🌐 [IRC] ⚠️ #globalchat fue cerrado manualmente anteriormente, no se volverá a abrir',
            );
          } else if (_hasAutoJoinedGlobalChat) {
            debugLog(
              '🌐 [IRC] ⚠️ Autojoin a #globalchat ya se hizo, no se repetirá',
            );
          }
          break;

        case '332': // TOPIC
          // debugLog('🔍 [DEBUG] 📌📌📌 TOPIC command received! Raw line: $line');
          // debugLog('🔍 [DEBUG] 📌📌📌 Full line breakdown:');
          // debugLog('🔍 [DEBUG] 📌📌📌   - Line length: ${line.length}');
          // debugLog('🔍 [DEBUG] 📌📌📌   - Parts count: ${parts.length}');
          // debugLog('🔍 [DEBUG] 📌📌📌   - Args count: ${args.length}');
          // debugLog('🔍 [DEBUG] 📌📌📌   - Args: $args');
          // debugLog('🔍 [DEBUG] 📌📌📌   - Source: $source');
          // debugLog('🔍 [DEBUG] 📌📌📌   - Command: $command');

          // El formato típico es: :server 332 nick #channel :topic text
          // Pero también puede ser: :server 332 #channel :topic text (sin nick)
          String? channel;
          String? topicText;

          // Intentar extraer el canal y el topic
          if (args.isNotEmpty) {
            // El canal puede estar en args[0] o args[1] dependiendo del formato
            var potentialChannel = args.length >= 2 ? args[1] : args[0];

            // Si el primer arg no parece un canal, intentar el segundo
            if (!potentialChannel.startsWith('#') && args.length >= 2) {
              potentialChannel = args[0];
            }

            // debugLog('🔍 [DEBUG] 📌📌📌 Potential channel from args: "$potentialChannel"');
            // Guardar el canal original antes de normalizar para buscarlo en la línea
            final originalChannelInLine = potentialChannel;
            channel = _normalizeChannelName(potentialChannel);
            // debugLog('🔍 [DEBUG] 📌📌📌 Normalized channel: "$channel"');

            // Extraer el topic: el formato es :server 332 nick #channel :topic
            // Necesitamos encontrar el ':' que viene después del nombre del canal
            // Buscar el canal ORIGINAL (sin normalizar) en la línea y luego el ':' que viene después
            final channelIndex = line.indexOf(originalChannelInLine);
            if (channelIndex != -1) {
              // Buscar el ':' que viene después del nombre del canal
              final colonIndex = line.indexOf(
                ':',
                channelIndex + originalChannelInLine.length,
              );
              // debugLog('🔍 [DEBUG] 📌📌📌 Channel index: $channelIndex, Colon index after channel: $colonIndex');

              if (colonIndex != -1 && colonIndex < line.length - 1) {
                final rawTopic = line.substring(colonIndex + 1).trim();
                // Limpiar códigos de formato IRC (colores, subrayado, etc.) para que se vean bien en el topic
                topicText = IRCColorParser.stripIRCFormatting(rawTopic);
                // debugLog('🔍 [DEBUG] 📌📌📌 Topic text extracted (raw): "$rawTopic"');
                // debugLog('🔍 [DEBUG] 📌📌📌 Topic text cleaned: "$topicText"');
                // debugLog('🔍 [DEBUG] 📌📌📌 Topic text length: ${topicText.length}');
              } else {
                // debugLog('🔍 [DEBUG] 📌📌📌 ⚠️  No colon found after channel name');
              }
            } else {
              // debugLog('🔍 [DEBUG] 📌📌📌 ⚠️  Channel not found in line (searched for: "$originalChannelInLine")');
            }
          }

          if (channel != null && channel.startsWith('#')) {
            // Usar una variable local no-nullable para evitar problemas de tipos
            String finalChannel = channel;

            // Buscar el canal en el mapa (case-insensitive)
            if (!channels.containsKey(finalChannel)) {
              // debugLog('🔍 [DEBUG] 📌📌📌 Channel "$finalChannel" not found, searching case-insensitive...');
              // debugLog('🔍 [DEBUG] 📌📌📌 Available channels: ${channels.keys.toList()}');
              // Buscar case-insensitive
              for (var existingKey in channels.keys) {
                if (existingKey.toLowerCase() == finalChannel.toLowerCase()) {
                  finalChannel = existingKey;
                  // debugLog('🔍 [DEBUG] 📌📌📌 Found channel case-insensitive: "$finalChannel"');
                  break;
                }
              }
            }

            // Si el canal existe, actualizar el topic
            if (channels.containsKey(finalChannel)) {
              if (topicText != null) {
                channels[finalChannel]!.setTopic(topicText);
                // debugLog('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic set for existing channel: $finalChannel');
                // debugLog('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic value: "${channels[finalChannel]!.topic}"');
              } else {
                // Si no hay topic, establecer como vacío
                channels[finalChannel]!.setTopic('');
                // debugLog('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic cleared for channel: $finalChannel');
              }
              // Notificar cambio de topic
              _notifyTopicListeners(finalChannel);
              // debugLog('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic listeners notified');
            } else {
              // Crear el canal si no existe
              channels[finalChannel] = IRCChannel(
                name: finalChannel,
                topic: topicText ?? '',
              );
              // debugLog('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic set for new channel: $finalChannel');
              // debugLog('🔍 [DEBUG] 📌📌📌 ✅✅✅ Topic value: "${channels[finalChannel]!.topic}"');
              _notifyTopicListeners(finalChannel);
            }
          } else {
            // debugLog('🔍 [DEBUG] 📌📌📌 ⚠️  ⚠️  ⚠️  Invalid channel in TOPIC command: $channel');
            // debugLog('🔍 [DEBUG] 📌📌📌 ⚠️  ⚠️  ⚠️  Full line for inspection: $line');
          }
          break;

        case '433': // Nickname in use - try alternative
          debugLog(
            '⚠️ [IRCService] Error 433 recibido - Nickname in use: $_nickname',
          );
          debugLog('⚠️ [IRCService] Línea completa: $line');

          // Verificar que el mensaje realmente dice que el nick está en uso
          final lineLower = line.toLowerCase();
          final isNickInUse =
              lineLower.contains('nickname is already in use') ||
              lineLower.contains('nick already in use') ||
              lineLower.contains('nickname already in use');

          if (!isNickInUse) {
            debugLog(
              '⚠️ [IRCService] Error 433 recibido pero el mensaje no indica que el nick esté en uso. Ignorando.',
            );
            break;
          }

          if (_nickname == null) {
            debugLog(
              '⚠️ [IRCService] Nick es null, no se puede buscar alternativa.',
            );
            break;
          }

          // Buscar un nick alternativo
          String newNick;

          // Si es ZNC, usar el username de ZNC directamente
          if (_zncUsername != null && _zncUsername!.isNotEmpty) {
            newNick = _zncUsername!;
            debugLog(
              '⚠️ [IRCService] Nick en uso (ZNC), usando username de ZNC: $_nickname -> $newNick',
            );
          } else if (_originalNickname != null && _nickAttempts < 10) {
            // Intentar con números: nick1, nick2, nick3, etc.
            _nickAttempts++;
            newNick = '$_originalNickname$_nickAttempts';
            debugLog(
              '⚠️ [IRCService] Nick en uso, intentando alternativa $_nickAttempts: $_nickname -> $newNick',
            );
          } else if (_nickname != null && !_nickname!.endsWith('_')) {
            // Si ya probamos números o no hay nick original, usar guion
            newNick = '${_nickname}_';
            debugLog(
              '⚠️ [IRCService] Nick en uso, añadiendo guion: $_nickname -> $newNick',
            );
          } else if (_nickname != null) {
            // Si ya termina en guion, añadir otro
            newNick = '${_nickname}_';
            debugLog(
              '⚠️ [IRCService] Nick en uso, añadiendo otro guion: $_nickname -> $newNick',
            );
          } else {
            // Fallback si _nickname es null (no debería pasar, pero por seguridad)
            newNick = 'user${_nickAttempts + 1}';
            _nickAttempts++;
            debugLog('⚠️ [IRCService] Nick es null, usando fallback: $newNick');
          }

          _nickname = newNick;
          _sessionNickname = newNick;
          _sendCommand('NICK $newNick');

          // Notificar a los listeners del cambio de nick
          for (var listener in _nickChangeListeners) {
            try {
              listener(newNick);
            } catch (e) {
              // Ignorar errores en listeners
            }
          }
          break;

        case '353': // Names reply (users in channel)
          // Método más simple y robusto: buscar cualquier palabra que empiece con # en la línea
          String? channel;

          // Primero intentar con regex para encontrar cualquier #canal en la línea
          final channelMatch = RegExp(r'(#\S+)').firstMatch(line);
          if (channelMatch != null) channel = channelMatch.group(1);
          if (channel == null || !channel.startsWith('#')) {
            for (var arg in args) {
              if (arg.startsWith('#')) {
                channel = arg;
                break;
              }
            }
          }
          if (channel == null || !channel.startsWith('#')) {
            if (args.length >= 3) {
              if (args[1] == '=' ||
                  args[1] == '@' ||
                  args[1] == '&' ||
                  args[1] == '*') {
                channel = args[2];
              } else if (args[1].startsWith('#')) {
                channel = args[1];
              } else if (args[2].startsWith('#')) {
                channel = args[2];
              }
            } else if (args.length >= 2) {
              channel = args[1];
            }
          }
          if (channel == null || channel.isEmpty || !channel.startsWith('#')) {
            break;
          }
          String originalChannel = channel;
          channel = _normalizeChannelName(channel);

          // En este punto, channel no puede ser null (ya validado arriba)
          final validChannel = channel;

          // Validación CRÍTICA: el canal NO debe ser igual al nickname (con o sin #)
          // Esto evita crear canales como #flutteruser cuando el nickname es FlutterUser
          if (_nickname != null) {
            final normalizedNick = _nickname!.toLowerCase();
            final channelWithoutHash = validChannel.toLowerCase().replaceFirst(
              '#',
              '',
            );

            // Verificar si el canal es igual al nickname (con o sin #)
            if (channelWithoutHash == normalizedNick ||
                validChannel.toLowerCase() == '#$normalizedNick' ||
                originalChannel.toLowerCase() == normalizedNick) {
              break;
            }
          }

          // Si el canal no existe con el nombre exacto, buscar por nombre normalizado (case-insensitive)
          // Esto es importante porque el servidor puede devolver el nombre con diferente capitalización
          String finalChannel = validChannel;

          // Buscar el canal con el mismo nombre normalizado (case-insensitive)
          if (!channels.containsKey(validChannel)) {
            for (var existingKey in channels.keys) {
              if (existingKey.toLowerCase() == validChannel.toLowerCase()) {
                finalChannel = existingKey;
                break;
              }
            }
            if (!channels.containsKey(finalChannel)) break;
          }

          // Find the position of ':' to get the users list
          final colonIndex = line.indexOf(':');
          if (colonIndex != -1) {
            final usersList = line.substring(colonIndex + 1).trim();
            final users = usersList
                .split(' ')
                .where((u) => u.isNotEmpty)
                .toList();

            // Create channel if it doesn't exist (usar nombre normalizado)
            if (!channels.containsKey(finalChannel)) {
              // debugLog('🔍 [DEBUG] ℹ️  Channel not in map, creating it: $finalChannel');
              channels[finalChannel] = IRCChannel(name: finalChannel);
            } else {
              // debugLog('🔍 [DEBUG] ✅ Channel already exists: $finalChannel');
              // debugLog('🔍 [DEBUG] Current users in channel before update: ${channels[finalChannel]!.users}');
            }

            int addedCount = 0;
            int updatedCount = 0;
            // Agregar usuarios a la lista (addUser ya verifica duplicados)
            for (var user in users) {
              // Extraer el prefijo de modo IRC antes de limpiar
              String? userMode;
              String cleanUser = user.trim();

              // Detectar prefijos IRC: ~ (owner), @ (op), + (voice), % (halfop), & (founder/owner), ! (admin), h (halfop)
              if (cleanUser.startsWith('~')) {
                userMode = '~';
                cleanUser = cleanUser.substring(1).trim();
              } else if (cleanUser.startsWith('@')) {
                userMode = '@';
                cleanUser = cleanUser.substring(1).trim();
              } else if (cleanUser.startsWith('&')) {
                userMode = '&';
                cleanUser = cleanUser.substring(1).trim();
              } else if (cleanUser.startsWith('%')) {
                userMode = '%';
                cleanUser = cleanUser.substring(1).trim();
              } else if (cleanUser.startsWith('!')) {
                userMode = '!';
                cleanUser = cleanUser.substring(1).trim();
              } else if (cleanUser.startsWith('h')) {
                userMode = 'h';
                cleanUser = cleanUser.substring(1).trim();
              } else if (cleanUser.startsWith('+')) {
                userMode = '+';
                cleanUser = cleanUser.substring(1).trim();
              } else if (cleanUser.startsWith(':')) {
                cleanUser = cleanUser.substring(1).trim();
              }

              // debugLog('🔍 [DEBUG] Processing user: "$user" -> mode: "$userMode", cleaned: "$cleanUser"');

              // Validar que no sea un servidor/host (excluir nombres con múltiples puntos o que parezcan dominios)
              final isServerHost =
                  cleanUser.contains('.') &&
                  (cleanUser.split('.').length >
                          2 || // Múltiples puntos (ej: ceres.globalchat.org)
                      RegExp(
                        r'\.(org|com|net|edu|gov|io|co|uk|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|pl|cz|sk|hu|ro|bg|gr|pt|ie|lu|mt|cy|ee|lv|lt|si|hr|rs|ba|mk|al|me|is|li|ad|mc|sm|va|by|ua|md|ge|am|az|kz|uz|tm|tj|kg|mn|cn|jp|kr|in|au|nz|za|br|mx|ar|cl|co|pe|ve|ec|uy|py|bo|cr|pa|do|gt|hn|ni|sv|bz|jm|tt|bb|gd|lc|vc|ag|bs|dm|kn|sr|gy|fk|ai|vg|ky|bm|tc|ms|pw|fm|mh|nr|ki|tv|to|ws|sb|vu|nc|pf|as|gu|mp|pr|vi|um|us|ca)$',
                        caseSensitive: false,
                      ).hasMatch(cleanUser)); // Termina en dominio común

              // Only add if it's a valid username (alphanumeric, underscore, hyphen)
              // and doesn't start with # or : or numbers only
              // and is not a server/host name
              if (cleanUser.isNotEmpty &&
                  !cleanUser.startsWith(':') &&
                  !cleanUser.startsWith('#') &&
                  !isServerHost &&
                  RegExp(r'^[a-zA-Z_\-][a-zA-Z0-9_\-]*$').hasMatch(cleanUser)) {
                // Removido el punto de la regex
                // Verificar si el usuario ya existe (case-insensitive)
                final cleanUserLower = cleanUser.toLowerCase();
                String? existingUser;
                for (var user in channels[finalChannel]!.users) {
                  if (user.toLowerCase() == cleanUserLower) {
                    existingUser = user;
                    break;
                  }
                }

                // Si el usuario ya existe, actualizar su modo
                if (existingUser != null) {
                  // Siempre actualizar el modo si se proporciona uno, incluso si el usuario ya existe
                  if (userMode != null) {
                    channels[finalChannel]!.addUser(
                      existingUser,
                      mode: userMode,
                    );
                    updatedCount++;
                    debugLog(
                      '🔍 [DEBUG] ✅ Updated mode for existing user: "$existingUser" -> "$userMode"',
                    );
                  }
                  // Si no tiene modo en este mensaje NAMES, NO hacer nada - mantener el modo existente
                  // (no limpiar el modo si el usuario viene sin prefijo en algún mensaje)
                } else {
                  debugLog(
                    '🔍 [DEBUG] ➕ Adding new user: "$cleanUser" with mode: "$userMode"',
                  );
                  channels[finalChannel]!.addUser(cleanUser, mode: userMode);
                  addedCount++;

                  // Hacer WHOIS automático para detectar estado away (con delay para evitar spam)
                  Future.delayed(const Duration(seconds: 2), () {
                    if (_isConnected && _hasActiveConnection) {
                      // Solo hacer WHOIS si no tenemos información reciente en caché
                      final cachedInfo = _whoisCache[cleanUser.toLowerCase()];
                      final shouldRequestWhois =
                          cachedInfo == null ||
                          (cachedInfo.signonTime != null &&
                              DateTime.now().difference(
                                    cachedInfo.signonTime!,
                                  ) >
                                  const Duration(minutes: 5));

                      if (shouldRequestWhois) {
                        sendWhois(cleanUser);
                      }
                    }
                  });
                }
              } else {
                if (isServerHost) {
                  // debugLog('🔍 [DEBUG] ❌ Skipping server/host name: "$cleanUser"');
                } else {
                  // debugLog('🔍 [DEBUG] ❌ Skipping invalid user: "$cleanUser"');
                }
              }
            }

            debugLog(
              '🔍 [DEBUG] Added $addedCount new users, updated $updatedCount existing users',
            );
            debugLog(
              '🔍 [DEBUG] Total users in channel now: ${channels[finalChannel]!.users.length}',
            );
            debugLog('🔍 [DEBUG] Users list: ${channels[finalChannel]!.users}');
            // Debug: mostrar modos de todos los usuarios
            debugLog('🔍 [DEBUG] User modes after NAMES processing:');
            for (var u in channels[finalChannel]!.users) {
              channels[finalChannel]!.getUserMode(u);
            }

            // Notificar que la lista de usuarios se actualizó
            // debugLog('🔍 [DEBUG] Notifying user list listeners for channel: $finalChannel');
            _notifyUserListListeners(finalChannel);
            // debugLog('🔍 [DEBUG] ✅ User list updated for $channel with ${channels[channel]!.users.length} users');
          } else {
            debugLog(
              '🔍 [DEBUG] ⚠️  No colon found in line, cannot parse users',
            );
          }
          break;

        case '366': // End of NAMES list
          debugLog('📋 End of NAMES list (366)');
          if (args.length >= 2) {
            var channel = args[1];
            channel = _normalizeChannelName(channel);
            if (channels.containsKey(channel)) {
              if (_isListedInChannelUsers(channel)) {
                _serverConfirmedChannels.add(channel);
                _pendingJoinChannels.remove(channel);
              }
              _notifyUserListListeners(channel);
              Future.delayed(const Duration(milliseconds: 500), () {
                if (channels.containsKey(channel)) sendWho(channel);
              });
            }
          }
          break;

        case 'NICK':
          // El servidor confirma el cambio de nick
          // Formato: :oldnick!user@host NICK :newnick
          // O: :oldnick NICK :newnick
          // debugLog('🔄 [IRCService] 🔴🔴🔴 NICK command received - Full line: $line');
          // debugLog('🔄 [IRCService] NICK command - source: $source, command: $command, args: $args');
          // debugLog('🔄 [IRCService] NICK command - parts: $parts');
          // debugLog('🔄 [IRCService] NICK command - nick from source: $nick');

          if (args.isNotEmpty) {
            // El nuevo nick puede estar en args[0] con o sin ':'
            var newNick = args[0];
            if (newNick.startsWith(':')) {
              newNick = newNick.substring(1);
            }
            newNick = newNick.trim();

            // El oldNick viene del source (antes del !)
            final oldNick = nick;

            // debugLog('🔄 [IRCService] NICK parsed - oldNick="$oldNick", newNick="$newNick", our nickname="$_nickname"');
            // debugLog('🔄 [IRCService] Comparación: oldNick.toLowerCase()="${oldNick?.toLowerCase()}" == _nickname.toLowerCase()="${_nickname?.toLowerCase()}"');
            // debugLog('🔄 [IRCService] ¿Son iguales?: ${oldNick != null && _nickname != null && oldNick.toLowerCase() == _nickname!.toLowerCase()}');

            // Si es nuestro propio cambio de nick
            if (_nickname != null &&
                oldNick.toLowerCase() == _nickname!.toLowerCase()) {
              // debugLog('🔄 [IRCService] ✅✅✅ Nuestro nick cambió de "$oldNick" a "$newNick"');
              _nickname = newNick;
              _sessionNickname = newNick;
              // debugLog('🔄 [IRCService] _nickname actualizado a: "$_nickname"');

              // Actualizar el nick en todos los canales donde aparezca nuestro nick antiguo
              debugLog('🔄 [IRCService] Actualizando nick en canales...');
              final oldNickLower = oldNick.toLowerCase();
              for (var channel in channels.values) {
                // Buscar el usuario de forma case-insensitive
                String? existingNick;
                for (var user in channel.users) {
                  if (user.toLowerCase() == oldNickLower) {
                    existingNick = user;
                    break;
                  }
                }

                if (existingNick != null) {
                  // Guardar host y modo del usuario antiguo si existen
                  final oldHost = channel.userHosts[existingNick];
                  final oldMode = channel.userModes[existingNick];

                  // Remover el usuario antiguo
                  channel.users.remove(existingNick);
                  if (channel.userHosts.containsKey(existingNick)) {
                    channel.userHosts.remove(existingNick);
                  }
                  if (channel.userModes.containsKey(existingNick)) {
                    channel.userModes.remove(existingNick);
                  }

                  // Agregar el usuario con el nuevo nick y restaurar host/modo
                  channel.users.add(newNick);
                  if (oldHost != null) {
                    channel.userHosts[newNick] = oldHost;
                  }
                  if (oldMode != null) {
                    channel.userModes[newNick] = oldMode;
                  }

                  _notifyUserListListeners(channel.name);
                  // debugLog('🔄 [IRCService] Actualizando nick en canal "${channel.name}": "$existingNick" -> "$newNick"');
                }
              }

              // debugLog('🔄 [IRCService] Notificando ${_nickChangeListeners.length} listeners...');
              // Notificar a los listeners del cambio de nick
              for (var i = 0; i < _nickChangeListeners.length; i++) {
                try {
                  // debugLog('🔄 [IRCService] Llamando listener $i con: "$newNick"');
                  _nickChangeListeners[i](newNick);
                  // debugLog('🔄 [IRCService] Listener $i llamado exitosamente');
                } catch (e) {
                  // debugLog('⚠️  [IRCService] Error en listener $i de cambio de nick: $e');
                }
              }
              // debugLog('🔄 [IRCService] ✅ Todos los listeners notificados');

              // Nota: En IRC estándar, cuando cambias tu nick NO te expulsan de los canales.
              // El servidor simplemente actualiza tu nick en todos los canales donde estás.
              // Ya hemos actualizado el nick en todos los canales arriba, así que no necesitamos cerrarlos.
              // Si el servidor realmente te expulsa, recibiremos mensajes PART o KICK y los manejaremos entonces.
            } else {
              // Es el cambio de nick de otro usuario
              // debugLog('🔄 [IRCService] Usuario "$oldNick" cambió su nick a "$newNick" (no es nuestro)');
              // Actualizar el nick en todos los canales donde aparezca (case-insensitive)
              final oldNickLower = oldNick.toLowerCase();
              for (var channel in channels.values) {
                // Buscar el usuario de forma case-insensitive
                String? existingNick;
                for (var user in channel.users) {
                  if (user.toLowerCase() == oldNickLower) {
                    existingNick = user;
                    break;
                  }
                }

                if (existingNick != null) {
                  // Guardar host y modo del usuario antiguo si existen
                  final oldHost = channel.userHosts[existingNick];
                  final oldMode = channel.userModes[existingNick];

                  // Remover el usuario antiguo
                  channel.users.remove(existingNick);
                  if (channel.userHosts.containsKey(existingNick)) {
                    channel.userHosts.remove(existingNick);
                  }
                  if (channel.userModes.containsKey(existingNick)) {
                    channel.userModes.remove(existingNick);
                  }

                  // Agregar el usuario con el nuevo nick y restaurar host/modo
                  channel.users.add(newNick);
                  if (oldHost != null) {
                    channel.userHosts[newNick] = oldHost;
                  }
                  if (oldMode != null) {
                    channel.userModes[newNick] = oldMode;
                  }

                  _notifyUserListListeners(channel.name);
                  debugLog(
                    '🔄 [IRCService] Nick actualizado en ${channel.name}: "$existingNick" -> "$newNick"',
                  );

                  // Agregar mensaje de sistema al canal
                  final nickMsg = IRCMessage(
                    nick: oldNick ?? '',
                    channel: channel.name,
                    message: 'ahora es $newNick',
                    timestamp: DateTime.now(),
                    isSystem: true,
                    messageId: IRCMessage.generateMessageId(),
                  );
                  channel.addMessage(nickMsg);
                  _notifyMessageListeners(nickMsg);
                }
              }
            }
          } else {
            // debugLog('⚠️  [IRCService] NICK command sin argumentos: $line');
          }
          break;

        case 'JOIN':
          debugLog(
            '🚪 [IRC] JOIN recibido: $nick se unió a ${args.isNotEmpty ? args[0] : "canal desconocido"}',
          );

          if (args.isNotEmpty) {
            var channel = args[0];
            channel = _normalizeChannelName(channel);

            // Solo procesar si es un canal válido
            if (!channel.startsWith('#')) {
              debugLog('⚠️ [IRC] Invalid channel name in JOIN: $channel');
              break;
            }

            if (!channels.containsKey(channel)) {
              channels[channel] = IRCChannel(name: channel);
              debugLog('✅ [IRC] Canal creado: $channel');
            }

            // Si somos nosotros los que nos unimos
            if (nick == _nickname) {
              debugLog('✅ [IRC] ¡Nos unimos exitosamente al canal: $channel!');
              _currentChannel = channel;
              _serverConfirmedChannels.add(channel);
              _pendingJoinChannels.remove(channel);
            }

            // Validar que el nick no sea un servidor/host antes de agregarlo
            final isServerHost =
                nick.contains('.') &&
                (nick.split('.').length >
                        2 || // Múltiples puntos (ej: ceres.globalchat.org)
                    RegExp(
                      r'\.(org|com|net|edu|gov|io|co|uk|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|pl|cz|sk|hu|ro|bg|gr|pt|ie|lu|mt|cy|ee|lv|lt|si|hr|rs|ba|mk|al|me|is|li|ad|mc|sm|va|by|ua|md|ge|am|az|kz|uz|tm|tj|kg|mn|cn|jp|kr|in|au|nz|za|br|mx|ar|cl|co|pe|ve|ec|uy|py|bo|cr|pa|do|gt|hn|ni|sv|bz|jm|tt|bb|gd|lc|vc|ag|bs|dm|kn|sr|gy|fk|ai|vg|ky|bm|tc|ms|pw|fm|mh|nr|ki|tv|to|ws|sb|vu|nc|pf|as|gu|mp|pr|vi|um|us|ca)$',
                      caseSensitive: false,
                    ).hasMatch(nick)); // Termina en dominio común

            if (!isServerHost) {
              // Verificar si el usuario ya existe antes de agregarlo
              final nickLower = nick.toLowerCase();
              final channelObj = channels[channel]!;
              bool userExists = false;
              for (var existingUser in channelObj.users) {
                if (existingUser.toLowerCase() == nickLower) {
                  userExists = true;
                  break;
                }
              }

              if (!userExists) {
                channels[channel]!.addUser(nick, host: host);
                // debugLog('🔍 [DEBUG] Added user "$nick" to channel "$channel" with host: ${host ?? "unknown"}');

                // Hacer WHOIS automático para detectar estado away (con delay para evitar spam)
                Future.delayed(const Duration(seconds: 2), () {
                  if (_isConnected && _hasActiveConnection) {
                    // Solo hacer WHOIS si no tenemos información reciente en caché
                    final cachedInfo = _whoisCache[nickLower];
                    final shouldRequestWhois =
                        cachedInfo == null ||
                        (cachedInfo.signonTime != null &&
                            DateTime.now().difference(cachedInfo.signonTime!) >
                                const Duration(minutes: 5));

                    if (shouldRequestWhois) {
                      sendWhois(nick);
                    }
                  }
                });
              }

              // Notificar cambio en la lista de usuarios
              _notifyUserListListeners(channel);
            } else {
              // debugLog('🔍 [DEBUG] ❌ Skipping server/host name in JOIN: "$nick"');
            }

            final msg = IRCMessage(
              nick: nick,
              channel: channel,
              message: '→ se unió al canal',
              timestamp: DateTime.now(),
              isSystem: true,
              messageId: IRCMessage.generateMessageId(),
            );
            channels[channel]!.addMessage(msg);
            _notifyMessageListeners(msg);

            // Si es nuestro propio JOIN, solicitar la lista de usuarios
            final isOurJoin = nick == _nickname;
            // debugLog('🔍 [DEBUG] JOIN check: nick="$nick" == nickname="$_nickname" ? $isOurJoin');

            if (isOurJoin) {
              debugLog('🔍 [DEBUG] ✅✅✅ Our own JOIN detected! ✅✅✅');
              debugLog('🔍 [DEBUG] Requesting NAMES for $channel (immediate)');
              _sendCommand('NAMES $channel');

              // Solicitar el TOPIC del canal
              // debugLog('🔍 [DEBUG] Requesting TOPIC for $channel (immediate)');
              _sendCommand('TOPIC $channel');

              // Detectar si es un canal especial de ayuda (#ayuda, #cau) o juego (#werewolf)
              final channelLower = channel.toLowerCase();
              if (channelLower == '#ayuda' || channelLower == '#cau') {
                debugLog('🤖 [IRC] Detectado canal de ayuda: $channel');
                // Notificar a los listeners después de un pequeño delay para asegurar que el canal está listo
                Future.delayed(const Duration(milliseconds: 500), () {
                  _notifyHelpChannelJoinListeners(channel);
                });
              } else if (channelLower == '#werewolf') {
                debugLog(
                  '🐺 [IRC] Detectado canal de juego Werewolf: $channel',
                );
                Future.delayed(const Duration(milliseconds: 500), () {
                  _notifyWerewolfChannelJoinListeners(channel);
                });
              }

              // También solicitar después de delays
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_isConnected && _hasActiveConnection) {
                  // debugLog('🔍 [DEBUG] Requesting NAMES for $channel (delayed 500ms)');
                  _sendCommand('NAMES $channel');
                  // debugLog('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 500ms)');
                  _sendCommand('TOPIC $channel');
                }
              });

              Future.delayed(const Duration(milliseconds: 1500), () {
                if (_isConnected && _hasActiveConnection) {
                  // debugLog('🔍 [DEBUG] Requesting NAMES for $channel (delayed 1500ms)');
                  _sendCommand('NAMES $channel');
                  // debugLog('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 1500ms)');
                  _sendCommand('TOPIC $channel');
                }
              });

              Future.delayed(const Duration(milliseconds: 3000), () {
                if (_isConnected && _hasActiveConnection) {
                  // debugLog('🔍 [DEBUG] Requesting NAMES for $channel (delayed 3000ms)');
                  _sendCommand('NAMES $channel');
                  // debugLog('🔍 [DEBUG] Requesting TOPIC for $channel (delayed 3000ms)');
                  _sendCommand('TOPIC $channel');
                }
              });
            } else {
              // debugLog('🔍 [DEBUG] ❌ Not our JOIN: nick="$nick" != nickname="$_nickname"');
            }
          } else {
            // debugLog('🔍 [DEBUG] ⚠️  JOIN command with no args');
          }
          break;

        case 'PART':
          if (args.isNotEmpty) {
            var channel = args[0];
            channel = _normalizeChannelName(channel);

            // Verificar si es nuestro propio PART
            final isOurPart =
                _nickname != null &&
                nick.toLowerCase() == _nickname!.toLowerCase();
            final isGlobalChat = channel.toLowerCase() == '#globalchat';

            if (channels.containsKey(channel)) {
              channels[channel]!.removeUser(nick);

              final msg = IRCMessage(
                nick: nick,
                channel: channel,
                message: '← dejó el canal',
                timestamp: DateTime.now(),
                messageId: IRCMessage.generateMessageId(),
                isSystem: true,
              );
              channels[channel]!.addMessage(msg);
              _notifyMessageListeners(msg);
              _notifyUserListListeners(channel);

              if (isOurPart) {
                _serverConfirmedChannels.remove(channel);
                if (isGlobalChat) {
                  _manuallyClosedChannels.add(channel.toLowerCase());
                  debugLog(
                    '🌐 [IRC] #globalchat cerrado manualmente (PART detectado), no se volverá a abrir automáticamente',
                  );
                }
                // Al salir nosotros, quitar el canal del mapa para que no siga en la lista y no "vuelva a meter" al tocarlo
                channels.remove(channel);
                _notifyUserListListeners(channel);
              }
            }
          }
          break;

        case 'KICK':
          // Formato: :nick!user@host KICK #channel target :reason
          if (args.length >= 2) {
            var channel = args[0];
            final kickedNick = args[1];
            channel = _normalizeChannelName(channel);

            if (channels.containsKey(channel)) {
              // Remover el usuario de la lista del canal
              channels[channel]!.removeUser(kickedNick);

              // Obtener la razón si existe
              final reason = args.length > 2
                  ? args.sublist(2).join(' ').replaceFirst(':', '').trim()
                  : null;

              final msg = IRCMessage(
                nick: nick,
                channel: channel,
                message: reason != null && reason.isNotEmpty
                    ? '⊘ expulsó a $kickedNick — $reason'
                    : '⊘ expulsó a $kickedNick',
                timestamp: DateTime.now(),
                isSystem: true,
                messageId: IRCMessage.generateMessageId(),
              );
              channels[channel]!.addMessage(msg);
              _notifyMessageListeners(msg);
              // Notificar cambio en la lista de usuarios
              _notifyUserListListeners(channel);
              // debugLog('👢 [IRCService] Usuario $kickedNick expulsado de $channel');

              // Si somos nosotros los expulsados, cerrar el canal y notificar
              if (_nickname != null &&
                  kickedNick.toLowerCase() == _nickname!.toLowerCase()) {
                _pendingJoinChannels.remove(channel);
                _serverConfirmedChannels.remove(channel);
                _untrackSessionChannel(channel);
                if (channels.containsKey(channel)) {
                  channels.remove(channel);
                  _notifyUserListListeners(channel);
                }
                if (_currentChannel == channel) {
                  _currentChannel = null;
                }
                // Notificar a los listeners de KICK
                for (var listener in _kickListeners) {
                  try {
                    listener(channel, reason ?? '');
                  } catch (e) {
                    debugLog('⚠️ [IRCService] Error en listener de KICK: $e');
                  }
                }
                debugLog(
                  '👢 [IRCService] Fuiste expulsado de $channel, canal cerrado',
                );
              }
            }
          }
          break;

        case 'MODE':
          // Formato: :source MODE #channel (+|-)(v|o|h|a|q) nick [nick ...]
          // Actualizar userModes en tiempo real cuando dan +v, -v, @, etc.
          // También gestiona cambios de modos del canal (p. ej. +m, +t) cuando
          // no hay nicks de destino.
          if (args.length >= 2 && args[0].startsWith('#')) {
            var channel = _normalizeChannelName(args[0]);
            final modeStr = args[1];
            if (!channels.containsKey(channel) || modeStr.isEmpty) {
              break;
            }
            final params =
                args.length > 2 ? args.sublist(2) : const <String>[];
            final channelObj = channels[channel]!;

            if (_applyChannelModeString(channelObj, modeStr, params)) {
              _notifyUserListListeners(channel);
            }
          }
          break;

        case '324': // RPL_CHANNELMODEIS: :server 324 nick #chan +ntmkl clave limite
          if (args.length >= 3) {
            final chanName = args[1];
            if (chanName.startsWith('#')) {
              final normalized = _normalizeChannelName(chanName);
              if (channels.containsKey(normalized)) {
                final modeStr = args[2].replaceFirst(':', '');
                final params = args.length > 3
                    ? args.sublist(3).map((p) => p.replaceFirst(':', '')).toList()
                    : const <String>[];
                channels[normalized]!.channelModes.clear();
                channels[normalized]!.key = null;
                channels[normalized]!.limit = null;
                if (_applyChannelModeString(
                  channels[normalized]!,
                  modeStr,
                  params,
                )) {
                  _notifyUserListListeners(normalized);
                }
              }
            }
          }
          break;

        case '367': // RPL_BANLIST: :server 367 nick #chan mask setter timestamp
          if (args.length >= 3) {
            final chanName = args[1];
            final normalized = _normalizeChannelName(chanName);
            if (channels.containsKey(normalized)) {
              final mask = args[2].replaceFirst(':', '');
              final setter = args.length > 3 ? args[3].replaceFirst(':', '') : '';
              DateTime? time;
              if (args.length > 4) {
                final ts = int.tryParse(args[4].replaceFirst(':', ''));
                if (ts != null && ts > 0) {
                  time = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
                }
              }
              channels[normalized]!.addBan(
                ChannelBan(mask: mask, setter: setter, time: time),
              );
              _notifyUserListListeners(normalized);
            }
          }
          break;

        case '368': // RPL_ENDOFBANLIST: :server 368 nick #chan :End of ban list
          // Noop: la lista de bans ya se llenó con los 367 previos.
          break;

        // WHOIS responses
        case '311': // WHOIS user info: :server 311 nick target username host * :realname
          if (args.length >= 5) {
            final targetNick = args[1];
            final username = args[2];
            final host = args[3];
            final realName = args.length > 5
                ? args.sublist(4).join(' ').replaceFirst(':', '').trim()
                : null;

            _pendingWhois[targetNick] = WhoisInfo(
              nick: targetNick,
              username: username,
              host: host,
              realName: realName,
            );

            // Actualizar el host en todos los canales donde esté el usuario (case-insensitive)
            final affectedChannels = <String>[];
            final targetNickLower = targetNick.toLowerCase();
            for (var channelEntry in channels.entries) {
              // Buscar el usuario de forma case-insensitive
              bool userExists = false;
              String? existingNick;
              for (var user in channelEntry.value.users) {
                if (user.toLowerCase() == targetNickLower) {
                  userExists = true;
                  existingNick = user;
                  break;
                }
              }
              if (userExists && existingNick != null) {
                channelEntry.value.addUser(existingNick, host: host);
                affectedChannels.add(channelEntry.key);
              }
            }
            // Notificar cambios en los canales afectados para actualizar la UI
            for (var channel in affectedChannels) {
              _notifyUserListListeners(channel);
            }
            // debugLog('🔍 [WHOIS] 311 - User info for $targetNick: $username@$host ($realName)');
          }
          break;

        case '312': // WHOIS server info: :server 312 nick target server :server info
          if (args.length >= 3) {
            final targetNick = args[1];
            final server = args[2];
            final serverInfo = args.length > 3
                ? args.sublist(3).join(' ').replaceFirst(':', '').trim()
                : null;

            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                server: server,
                serverInfo: serverInfo,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                server: server,
                serverInfo: serverInfo,
              );
            }
            // debugLog('🔍 [WHOIS] 312 - Server info for $targetNick: $server ($serverInfo)');
          }
          break;

        case '313': // WHOIS operator: :server 313 nick target :is an IRC Operator
          if (args.length >= 3) {
            final targetNick = args[1];
            // El resto de args suele contener el texto con el rol
            final roleText = args
                .sublist(2)
                .join(' ')
                .replaceFirst(':', '')
                .trim();

            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                isStaff: true,
                staffRole: roleText.isNotEmpty ? roleText : 'Operador IRC',
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                isStaff: true,
                staffRole: roleText.isNotEmpty ? roleText : 'Operador IRC',
              );
            }

            // Actualizar cache de IRCop si es el usuario actual
            if (targetNick.toLowerCase() == _nickname?.toLowerCase()) {
              _isIRCOp = true;
            }

            // debugLog('🔍 [WHOIS] 313 - $targetNick staff: ${_pendingWhois[targetNick]!.staffRole}');
          }
          break;

        case '381': // RPL_YOUREOPER: :server 381 nick :You are now an IRC Operator
          // El código 381 siempre es para el usuario que ejecutó OPER
          // Formato típico: :server 381 nick :You are now an IRC Operator
          // debugLog('🔍 [IRCService] Código 381 recibido, línea completa: $line');
          // debugLog('🔍 [IRCService] Args: $args, nuestro nick: $_nickname');

          // El código 381 siempre es para nosotros si lo recibimos
          // No necesitamos verificar el nick
          _isIRCOp = true;
          // debugLog('✅ [IRCService] Identificado como IRCop exitosamente (código 381)');

          // Notificar a los listeners de IRCop
          for (var listener in _ircopListeners) {
            listener();
          }
          break;

        case '491': // ERR_NOOPERHOST: :server 491 nick :No O-lines for your host
          if (args.length >= 2) {
            final targetNick = args[1];
            if (targetNick.toLowerCase() == _nickname?.toLowerCase()) {
              // debugLog('❌ [IRCService] Error: No tienes permisos de operador para este host');
            }
          }
          break;

        case '317': // WHOIS idle/signon: :server 317 nick target idle signon :seconds idle, signon time
          if (args.length >= 4) {
            final targetNick = args[1];
            final idleSeconds = int.tryParse(args[2]);
            final signonTimestamp = int.tryParse(args[3]);
            final signonTime = signonTimestamp != null
                ? DateTime.fromMillisecondsSinceEpoch(signonTimestamp * 1000)
                : null;

            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                idleSeconds: idleSeconds,
                signonTime: signonTime,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                idleSeconds: idleSeconds,
                signonTime: signonTime,
              );
            }
            // debugLog('🔍 [WHOIS] 317 - Idle/signon for $targetNick: ${idleSeconds}s idle, signed on: $signonTime');
          }
          break;

        case '318': // End of WHOIS: :server 318 nick target :End of /WHOIS list.
          if (args.length >= 2) {
            final targetNick = args[1];
            final targetNickLower = targetNick.toLowerCase();
            if (_pendingWhois.containsKey(targetNick)) {
              final whoisInfo = _pendingWhois[targetNick]!;
              _whoisCache[targetNickLower] = whoisInfo;
              _notifyWhoisListeners(whoisInfo);
              _pendingWhois.remove(targetNick);
              // Actualizar timestamp de última verificación
              _lastWhoisCheck[targetNickLower] = DateTime.now();
              // debugLog('🔍 [WHOIS] 318 - End of WHOIS for $targetNick');
            } else {
              // Si no hay información pendiente, crear una entrada básica para notificar
              // Esto puede pasar si el servidor envía 318 sin enviar otros códigos
              // debugLog('⚠️  [WHOIS] 318 recibido pero no hay información pendiente para $targetNick');
              final basicInfo = WhoisInfo(nick: targetNick);
              _whoisCache[targetNickLower] = basicInfo;
              _notifyWhoisListeners(basicInfo);
              // Actualizar timestamp de última verificación
              _lastWhoisCheck[targetNickLower] = DateTime.now();
            }
          }
          break;

        case '321': // RPL_LISTSTART: Inicio de lista de canales
          _listResults.clear();
          // debugLog('📋 [LIST] Iniciando lista de canales');
          break;

        case '322': // RPL_LIST: Información de un canal
          // Formato: :server 322 nick channel user_count :topic
          if (args.length >= 3) {
            final channel = args[1];
            final userCount = int.tryParse(args[2]) ?? 0;
            final topic = args.length > 3
                ? args.sublist(3).join(' ').replaceFirst(':', '').trim()
                : '';

            _listResults.add({
              'channel': channel,
              'users': userCount,
              'topic': topic,
            });
            // debugLog('📋 [LIST] Canal: $channel, Usuarios: $userCount, Topic: $topic');
          }
          break;

        case '323': // RPL_LISTEND: Fin de lista de canales
          _notifyListListeners(_listResults);
          // debugLog('📋 [LIST] Fin de lista (${_listResults.length} canales)');
          break;

        case '352': // RPL_WHOREPLY: Información de un usuario en WHO
          // Formato: :server 352 nick channel username host server nick status :realname
          if (args.length >= 7) {
            final channel = args[1];
            final username = args[2];
            final host = args[3];
            final server = args[4];
            final nick = args[5];
            final status = args[6];
            final realname = args.length > 7
                ? args.sublist(7).join(' ').replaceFirst(':', '').trim()
                : '';

            _whoResults.add({
              'channel': channel,
              'username': username,
              'host': host,
              'server': server,
              'nick': nick,
              'status': status,
              'realname': realname,
            });

            // Actualizar el host en el canal si existe
            final normalizedChannel = _normalizeChannelName(channel);
            if (channels.containsKey(normalizedChannel)) {
              channels[normalizedChannel]!.addUser(nick, host: host);
              // Notificar cambio en la lista de usuarios para actualizar la UI
              _notifyUserListListeners(normalizedChannel);
            }
            // debugLog('👤 [WHO] Usuario: $nick ($username@$host) en $channel, estado: $status');
          }
          break;

        case '315': // RPL_ENDOFWHO: Fin de WHO
          _notifyWhoListeners(_whoResults);
          // Notificar cambios en todos los canales afectados
          for (var result in _whoResults) {
            final channel = result['channel'] as String?;
            if (channel != null) {
              final normalizedChannel = _normalizeChannelName(channel);
              if (channels.containsKey(normalizedChannel)) {
                _notifyUserListListeners(normalizedChannel);
              }
            }
          }
          // debugLog('👤 [WHO] Fin de WHO (${_whoResults.length} usuarios)');
          _whoResults.clear(); // Limpiar después de notificar
          break;

        // Comandos IRCop - capturar respuestas genéricas
        case '364': // RPL_LINKS: Información de un servidor en LINKS
        case '371': // RPL_INFO: Línea de información (STATS, MOTD, etc.)
        case '372': // RPL_MOTD: Línea del mensaje del día
        case '373': // RPL_INFOSTART: Inicio de información
        case '374': // RPL_ENDOFINFO: Fin de información
        case '375': // RPL_MOTDSTART: Inicio de MOTD
        case '213': // RPL_STATSCOMMANDS: Estadísticas de comandos
        case '214': // RPL_STATSCLINE: Estadísticas de conexiones
        case '215': // RPL_STATSNLINE: Estadísticas de N-lines
        case '216': // RPL_STATSILINE: Estadísticas de I-lines
        case '217': // RPL_STATSKLINE: Estadísticas de K-lines
        case '218': // RPL_STATSYLINE: Estadísticas de Y-lines
        case '200': // RPL_TRACELINK: Información de TRACE
        case '201': // RPL_TRACECONNECTING: TRACE conectando
        case '202': // RPL_TRACEHANDSHAKE: TRACE handshake
        case '203': // RPL_TRACEUNKNOWN: TRACE desconocido
        case '204': // RPL_TRACEOPERATOR: TRACE operador
        case '205': // RPL_TRACEUSER: TRACE usuario
        case '206': // RPL_TRACESERVER: TRACE servidor
        case '208': // RPL_TRACENEWTYPE: TRACE nuevo tipo
        case '261': // RPL_TRACELOG: TRACE log
        case '006': // RPL_MAP: Línea del mapa
        case '234': // RPL_SERVLIST: Lista de servicios
          // Capturar líneas de respuesta de comandos IRCop
          if (_currentIRCOpCommand != null) {
            final message = args.length > 1
                ? args.sublist(1).join(' ').replaceFirst(':', '').trim()
                : '';
            if (message.isNotEmpty) {
              _ircopCommandResults.add(message);
              // debugLog('📋 [IRCOp] Respuesta de $_currentIRCOpCommand: $message');
            }
          }
          break;

        case '365': // RPL_ENDOFLINKS: Fin de LINKS
        case '219': // RPL_ENDOFSTATS: Fin de STATS
        case '262': // RPL_TRACEEND: Fin de TRACE
        case '007': // RPL_MAPEND: Fin de MAP
        case '376': // RPL_ENDOFMOTD: Fin de MOTD
        case '235': // RPL_SERVLISTEND: Fin de lista de servicios
          // Fin de comandos IRCop
          if (_currentIRCOpCommand != null) {
            _notifyIRCOpCommandListeners(_ircopCommandResults);
            // debugLog('📋 [IRCOp] Fin de $_currentIRCOpCommand (${_ircopCommandResults.length} líneas)');
            _ircopCommandResults.clear();
            _currentIRCOpCommand = null;
          }
          break;

        case '401': // ERR_NOSUCHNICK: :server 401 nick target :No such nick/channel
          if (args.length >= 2) {
            final targetNick = args[1];
            // debugLog('⚠️  [WHOIS] 401 - No such nick: $targetNick');
            // Notificar que el nick no existe
            final errorInfo = WhoisInfo(nick: targetNick);
            _whoisCache[targetNick.toLowerCase()] = errorInfo;
            _notifyWhoisListeners(errorInfo);
            _pendingWhois.remove(targetNick);

            // Si acabamos de enviar un PM a ese nick y el servidor responde
            // 401, el usuario ya no está conectado (o nunca existió).
            final queryKey = targetNick.toLowerCase();
            final lastSend = _recentPrivateSends[queryKey];
            if (lastSend != null &&
                DateTime.now().difference(lastSend).inSeconds < 30) {
              addSystemMessage(
                queryKey,
                'El usuario $targetNick ya no está conectado',
              );
              _recentPrivateSends.remove(queryKey);
            }
          }
          break;

        case '404': // ERR_CANNOTSENDTOCHAN
          if (args.length >= 2) {
            final channel = _normalizeChannelName(args[1]);
            final reason = args.length > 2
                ? args.sublist(2).join(' ').replaceFirst(':', '').trim()
                : '';
            debugLog(
              '⚠️ [IRCService] 404 Cannot send to channel: $channel',
            );
            if (!_channelJoinConfirmed(channel)) {
              _handleJoinRejected(
                channel,
                reason.isNotEmpty
                    ? reason
                    : 'No puedes acceder a este canal',
                404,
              );
            } else {
              _failLatestPendingInChannel(channel);
            }
          }
          break;

        case '405': // ERR_TOOMANYCHANNELS
        case '471': // ERR_CHANNELISFULL
        case '473': // ERR_INVITEONLYCHAN
        case '474': // ERR_BANNEDFROMCHAN
        case '475': // ERR_BADCHANNELKEY
        case '476': // ERR_BADCHANMASK
        case '477': // ERR_NEEDREGGEDNICK
          if (args.length >= 2) {
            final targetNick = args[0].replaceFirst(':', '').trim();
            if (_nickname != null &&
                targetNick.toLowerCase() != _nickname!.toLowerCase()) {
              break;
            }
            final channel = _normalizeChannelName(args[1]);
            final reason = args.length > 2
                ? args.sublist(2).join(' ').replaceFirst(':', '').trim()
                : '';
            _handleJoinRejected(
              channel,
              reason.isNotEmpty
                  ? reason
                  : joinRejectTitle(int.parse(command)),
              int.parse(command),
            );
          }
          break;

        case '319': // WHOIS channels: :server 319 nick target :#channel1 #channel2
          if (args.length >= 3) {
            final targetNick = args[1];
            final channelsStr = args
                .sublist(2)
                .join(' ')
                .replaceFirst(':', '')
                .trim();
            final channelsList = channelsStr
                .split(' ')
                .where((c) => c.isNotEmpty)
                .toList();

            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                channels: channelsList,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                channels: channelsList,
              );
            }
            // debugLog('🔍 [WHOIS] 319 - Channels for $targetNick: $channelsList');
          }
          break;

        case '671': // WHOIS secure connection (RPL_WHOISSECURE): :server 671 nick target :is using a secure connection
          if (args.length >= 2) {
            final targetNick = args[1];
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                isSecureConnection: true,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                isSecureConnection: true,
              );
            }
            // debugLog('🔍 [WHOIS] 671 - $targetNick is using a secure connection (SSL/TLS)');
          }
          break;

        case '301': // AWAY message: :server 301 nick target :away message
          if (args.length >= 3) {
            final targetNick = args[1];
            final awayMessage = args
                .sublist(2)
                .join(' ')
                .replaceFirst(':', '')
                .trim();

            // Actualizar información pendiente de WHOIS
            if (_pendingWhois.containsKey(targetNick)) {
              _pendingWhois[targetNick] = _pendingWhois[targetNick]!.copyWith(
                isAway: true,
                awayMessage: awayMessage,
              );
            } else {
              _pendingWhois[targetNick] = WhoisInfo(
                nick: targetNick,
                isAway: true,
                awayMessage: awayMessage,
              );
            }

            // También actualizar el caché y notificar inmediatamente para que se vea en los avatares
            final targetNickLower = targetNick.toLowerCase();
            final cachedInfo = _whoisCache[targetNickLower];
            if (cachedInfo != null) {
              // Actualizar información existente en caché
              final updatedInfo = cachedInfo.copyWith(
                isAway: true,
                awayMessage: awayMessage,
              );
              _whoisCache[targetNickLower] = updatedInfo;
              _notifyWhoisListeners(updatedInfo);
              // Actualizar timestamp de última verificación
              _lastWhoisCheck[targetNickLower] = DateTime.now();
            } else {
              // Crear nueva entrada en caché y notificar
              final newInfo = WhoisInfo(
                nick: targetNick,
                isAway: true,
                awayMessage: awayMessage,
              );
              _whoisCache[targetNickLower] = newInfo;
              _notifyWhoisListeners(newInfo);
              // Actualizar timestamp de última verificación
              _lastWhoisCheck[targetNickLower] = DateTime.now();
            }
            // debugLog('🔍 [WHOIS] 301 - $targetNick is away: $awayMessage');
          }
          break;

        case '305': // RPL_UNAWAY: Usuario ya no está en away
          // debugLog('✅ [IRCService] Ya no estás en away');
          _notifyAwayStatusListeners(false, null);

          // Actualizar también el caché de whois para que el avatar no muestre el indicador
          if (_nickname != null) {
            final nickLower = _nickname!.toLowerCase();
            final cachedInfo = _whoisCache[nickLower];
            if (cachedInfo != null) {
              final updatedInfo = cachedInfo.copyWith(
                isAway: false,
                awayMessage: null,
              );
              _whoisCache[nickLower] = updatedInfo;
              _notifyWhoisListeners(updatedInfo);
            }
          }
          break;

        case '306': // RPL_NOWAWAY: Usuario ahora está en away
          // El mensaje de away puede venir en args[1] o no
          // Nota: El servidor puede no incluir el mensaje en la respuesta 306
          // Si no viene, mantener el mensaje que ya tenemos en el estado local
          final awayMessage = args.length > 1
              ? args.sublist(1).join(' ').replaceFirst(':', '').trim()
              : null;
          // Si el mensaje viene vacío o null, mantener el mensaje actual del estado
          final finalAwayMessage =
              (awayMessage != null && awayMessage.isNotEmpty)
              ? awayMessage
              : (_whoisCache[_nickname?.toLowerCase() ?? '']?.awayMessage);
          // debugLog('🚶 [IRCService] Ahora estás en away${finalAwayMessage != null ? ": $finalAwayMessage" : ""}');
          _notifyAwayStatusListeners(true, finalAwayMessage);

          // Actualizar también el caché de whois
          if (_nickname != null) {
            final nickLower = _nickname!.toLowerCase();
            final cachedInfo = _whoisCache[nickLower];
            if (cachedInfo != null) {
              final updatedInfo = cachedInfo.copyWith(
                isAway: true,
                awayMessage: finalAwayMessage ?? cachedInfo.awayMessage,
              );
              _whoisCache[nickLower] = updatedInfo;
              _notifyWhoisListeners(updatedInfo);
            }
          }
          break;

        case 'PRIVMSG':
          if (args.isNotEmpty) {
            // No mostrar mensajes de StatServ ni Global (mismo criterio que en NOTICE)
            final privmsgSenderLower = nick.toLowerCase();
            if (privmsgSenderLower == 'statserv' ||
                privmsgSenderLower == 'global') {
              break;
            }
            // debugLog('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG recibido - Raw line: $line');
            // debugLog('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG - nick del source: "$nick", args: $args');

            var target = args[0];
            // debugLog('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG - target original: "$target"');
            // debugLog('🔍🔍🔍 [DEBUG PRIVMSG] 📨 PRIVMSG - nuestro nickname: "$_nickname"');

            var targetChannel = _normalizeChannelName(target);

            // Determinar si es un canal (#) o un mensaje privado (nick)
            bool isChannel = target.startsWith('#');
            String channelKey;

            // debugLog('🔍 [DEBUG] 📨 PRIVMSG - isChannel: $isChannel');

            if (isChannel) {
              // Es un canal, usar el nombre del canal normalizado
              channelKey = targetChannel;
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - Es un mensaje de canal: $channelKey');
            } else {
              // Es un mensaje privado
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - Es un mensaje privado (target no empieza con #)');
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - Comparando target "$target" (lowercase: ${target.toLowerCase()}) con nickname "$_nickname" (lowercase: ${_nickname?.toLowerCase()})');

              // Si el target es nuestro nickname, es un mensaje que NOS ENVIAN
              // En ese caso, usar el nick del remitente como channelKey
              // Si el target NO es nuestro nickname, es un mensaje que ENVIAMOS
              // En ese caso, usar el target como channelKey

              // Limpiar el target de posibles espacios o caracteres extra
              final cleanTarget = target.trim();
              final cleanNickname = _nickname?.trim();

              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - Comparación detallada:');
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - target limpio: "$cleanTarget" (length: ${cleanTarget.length})');
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - nickname limpio: "$cleanNickname" (length: ${cleanNickname?.length ?? 0})');
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - target.toLowerCase(): "${cleanTarget.toLowerCase()}"');
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - nickname.toLowerCase(): "${cleanNickname?.toLowerCase() ?? "null"}"');
              // debugLog('🔍 [DEBUG] 📨 PRIVMSG - ¿Son iguales?: ${cleanNickname != null && cleanTarget.toLowerCase() == cleanNickname.toLowerCase()}');

              if (cleanNickname != null &&
                  cleanTarget.toLowerCase() == cleanNickname.toLowerCase()) {
                // Mensaje privado que nos envían, usar el nick del remitente
                channelKey = nick.toLowerCase();
                // debugLog('🔍 [DEBUG] 📨 PRIVMSG: ✅✅✅ Mensaje privado RECIBIDO de "$nick", usando channelKey="$channelKey" ✅✅✅');

                // Verificar si el remitente está en la lista de ignorados (solo para mensajes que nos envían)
                final senderNick = nick.toLowerCase();
                if (_ignoredUsers.contains(senderNick)) {
                  // debugLog('🚫 [IRCService] Mensaje privado ignorado de usuario: $nick (en lista de ignorados: $_ignoredUsers)');

                  // Verificar si NO es un robot antes de enviar respuesta automática
                  final isBot = _isBotByHostOrNick(nick, host);
                  if (!isBot) {
                    // Enviar mensaje profesional al usuario ignorado como NOTICE
                    final responseMessage =
                        'Este usuario tiene protegido por el modo +P. No recibe mensajes privados. Para hablar con él, mándale un memo o un notice.';
                    sendPrivateNotice(nick, responseMessage, delaySeconds: 0);
                  }

                  break; // Ignorar el mensaje completamente
                }

                // Bloquear TODOS los mensajes privados si ignoreAllPrivates está activado
                if (_ignoreAllPrivates) {
                  final isBot = _isBotByHostOrNick(nick, host);
                  if (!isBot) {
                    sendPrivateNotice(nick, 'Este usuario tiene protegido por el modo +P. No recibe mensajes privados. Para hablar con él, mándale un memo o un notice.', delaySeconds: 0);
                    break;
                  }
                }

                // debugLog('✅ [IRCService] Mensaje privado de "$nick" NO está en lista de ignorados. Lista actual: $_ignoredUsers');
                // debugLog('✅ [IRCService] Procediendo a procesar mensaje privado de "$nick"');
              } else {
                // Mensaje privado que enviamos, usar el target
                channelKey = cleanTarget.toLowerCase();
                // debugLog('🔍 [DEBUG] 📨 PRIVMSG: Mensaje privado ENVIADO a "$cleanTarget", usando channelKey="$channelKey"');
              }
            }

            // Para mensajes de canal, también verificar si el remitente está ignorado
            if (isChannel) {
              final senderNick = nick.toLowerCase();
              if (_ignoredUsers.contains(senderNick)) {
                // debugLog('🚫 [IRCService] Mensaje de canal ignorado de usuario: $nick en $target');
                break; // Ignorar el mensaje completamente
              }
            }

            // Crear el canal/query si no existe
            final isNewChannel = !channels.containsKey(channelKey);
            if (isNewChannel) {
              channels[channelKey] = IRCChannel(name: channelKey);
              // debugLog('🔍 [DEBUG] Creado ${isChannel ? "canal" : "query"}: $channelKey');
            }

            // Agregar el usuario a la lista del canal si es un mensaje de canal
            // Esto asegura que todos los usuarios que envían mensajes aparezcan en la lista
            if (isChannel) {
              final channelObj = channels[channelKey]!;
              // Verificar si el usuario ya está en la lista (case-insensitive)
              final nickLower = nick.toLowerCase();
              bool userExists = false;
              for (var existingUser in channelObj.users) {
                if (existingUser.toLowerCase() == nickLower) {
                  userExists = true;
                  break;
                }
              }

              if (!userExists) {
                // Agregar el usuario (con host si está disponible)
                channelObj.addUser(nick, host: host);
                // Notificar cambio en la lista de usuarios
                _notifyUserListListeners(channelKey);
                // debugLog('🔍 [DEBUG] Usuario "$nick" agregado a la lista del canal "$channelKey" desde PRIVMSG');
              } else if (host != null) {
                // Si el usuario ya está en la lista pero tenemos un host nuevo, actualizarlo
                channelObj.addUser(nick, host: host);
                // Notificar para actualizar la UI
                _notifyUserListListeners(channelKey);
              }
            }

            // El formato es: :nick!user@host PRIVMSG target :mensaje
            final privmsgIndex = line.indexOf('PRIVMSG');
            if (privmsgIndex != -1) {
              // Encontrar el ':' que viene después del target
              final targetEndIndex =
                  line.indexOf(target, privmsgIndex) + target.length;
              final colonIndex = line.indexOf(':', targetEndIndex);

              if (colonIndex != -1) {
                // El mensaje es todo lo que viene después del ':'
                var messageContent = line.substring(colonIndex + 1).trim();



                // Detectar si el mensaje contiene información de respuesta (formato: mensaje [reply:messageId])
                String? extractedReplyToMessageId;
                final replyMatch = RegExp(
                  r'\[reply:([^\]]+)\]$',
                ).firstMatch(messageContent);
                if (replyMatch != null) {
                  extractedReplyToMessageId = replyMatch.group(1)!;
                  // Remover el [reply:messageId] del contenido del mensaje
                  messageContent = messageContent
                      .replaceFirst(RegExp(r'\s*\[reply:[^\]]+\]$'), '')
                      .trim();
                }

                messageContent = _decodeMultilineFromWire(messageContent);

                // Detectar CTCP TYPING (raw bytes y mensajes generados por el servidor)
                if (messageContent == '\x01TYPING\x01') {
                  if (nick.toLowerCase() != _nickname?.toLowerCase()) {
                    _notifyTypingListeners(channelKey, nick, true);
                  }
                  return;
                }
                if (messageContent == '\x01TYPING 0\x01') {
                  if (nick.toLowerCase() != _nickname?.toLowerCase()) {
                    _notifyTypingListeners(channelKey, nick, false);
                  }
                  return;
                }
                // Algunos servidores (ej. GlobalChat) convierten CTCP TYPING a texto legible
                if (messageContent.contains('\x01TYPING') ||
                    RegExp(r'CTCP\s+TYPING', caseSensitive: false)
                        .hasMatch(messageContent)) {
                  return;
                }

                // Detectar CTCP PING (poke/zumbido) de otro usuario
                if (messageContent.startsWith('\x01PING') &&
                    messageContent.endsWith('\x01') &&
                    nick.toLowerCase() != _nickname?.toLowerCase()) {
                  _notifyPokeListeners(nick);
                  return;
                }

                // Detectar y procesar mensajes ACTION (/me)
                bool isAction = false;
                String? actionText;
                if (messageContent.startsWith('\x01ACTION ') &&
                    messageContent.endsWith('\x01')) {
                  isAction = true;
                  // Extraer el texto de la acción (sin \x01ACTION y sin el \x01 final)
                  actionText = messageContent
                      .substring(8, messageContent.length - 1)
                      .trim();

                  // ¿La acción va dirigida a nosotros?
                  // - En privado (query) siempre va a nosotros.
                  // - En canal, la acción lleva el nick de destino tras el emoji.
                  bool isActionForMe = false;
                  if (!isChannel) {
                    isActionForMe = true;
                  } else {
                    final actionParts = actionText.split(' ');
                    final targetNick =
                        actionParts.length >= 2 ? actionParts[1].trim() : '';
                    isActionForMe =
                        targetNick.isNotEmpty &&
                        _nickname != null &&
                        targetNick.toLowerCase() ==
                            _nickname!.toLowerCase();
                  }

                  // Detectar si es un beso (ACTION con 💋)
                  if (actionText.startsWith('\u{1F48B}') &&
                      nick.toLowerCase() != _nickname?.toLowerCase() &&
                      isActionForMe) {
                    _notifyKissListeners(nick);
                  }

                  // Detectar acciones interactivas genéricas
                  if (nick.toLowerCase() != _nickname?.toLowerCase() &&
                      isActionForMe) {
                    final actionEmojiMap = {
                      '\u{1F44A}': 'poke',
                      '\u{1F44E}': 'poke',
                      '\u{1F44B}': 'wave',
                      '\u{1F91D}': 'highfive',
                      '\u{1F64F}': 'highfive',
                      '\u{1F917}': 'hug',
                      '\u{1F91A}': 'slap',
                      '\u{270B}': 'slap',
                      '\u{1FA78}': 'slap',
                      '\u{1F4A6}': 'spray',
                      '\u{1F4A7}': 'spray',
                      '\u{2615}': 'coffee',
                      '\u{1F37A}': 'beer',
                      '\u{1F37B}': 'beer',
                      '\u{1F525}': 'fire',
                      '\u{1F4B6}': 'money',
                    };
                    for (final entry in actionEmojiMap.entries) {
                      if (actionText.startsWith(entry.key)) {
                        _notifyActionListeners(entry.value, nick);
                        break;
                      }
                    }
                  }

                  // Detectar si es una reacción sincronizada (formato: +emoji [messageId])
                  final reactionMatch = RegExp(
                    r'^\+(\S+)\s+\[([^\]]+)\]$',
                  ).firstMatch(actionText);
                  if (reactionMatch != null) {
                    final emoji = reactionMatch.group(1)!;
                    final reactionMessageId = reactionMatch.group(2)!;

                    // Solo aplicar si no es nuestro propio mensaje (evitar duplicar reacciones propias)
                    if (_nickname == null ||
                        nick.toLowerCase() != _nickname!.toLowerCase()) {
                      // Aplicar la reacción al mensaje correspondiente
                      _applyReactionFromServer(
                        channelKey,
                        reactionMessageId,
                        emoji,
                        nick,
                      );
                    }

                    // No mostrar este mensaje ACTION como mensaje normal
                    return;
                  }

                  messageContent =
                      actionText; // Usar el texto de la acción como mensaje
                  // debugLog('🎭 [IRCService] Mensaje ACTION detectado: "$actionText"');
                }

                // Verificar si es una respuesta de STATUS de NickServ (viene como NOTICE pero se procesa como PRIVMSG)
                // Formato: :NickServ!NickServ@services.globalchat.org NOTICE nick :STATUS nick 3
                // O como PRIVMSG: :NickServ!NickServ@services.globalchat.org PRIVMSG nick :STATUS nick 3
                if ((nick.toLowerCase() == 'nickserv' ||
                        nick.toLowerCase() == 'nick') &&
                    messageContent.contains('STATUS')) {
                  final match = RegExp(
                    r'STATUS\s+(\S+)\s+(\d+)',
                  ).firstMatch(messageContent);
                  if (match != null) {
                    final checkedNick = match.group(1)!.toLowerCase();
                    final status = int.tryParse(match.group(2)!);
                    // debugLog('📋 [IRCService] Status recibido para nick "$checkedNick": $status');
                    final completer = _statusCheckCompleters.remove(
                      checkedNick,
                    );
                    if (completer != null && !completer.isCompleted) {
                      completer.complete(status);
                    }
                    // No procesar como mensaje normal si es una respuesta de STATUS
                    return;
                  }
                }

                // Ignorar SOLO el mensaje IDENTIFY que **nosotros** enviamos al bot "nick"
                // Formato típico ecoado por el servidor:
                //   :NuestroNick!user@host PRIVMSG nick :IDENTIFY NuestroNick password
                // - nick (source)  -> nuestro propio nick
                // - target         -> "nick"
                // - messageContent -> comienza por "IDENTIFY ..."
                //
                // Las respuestas del bot "nick" (por ejemplo "You are now identified")
                // NO deben coincidir con esta condición y se mostrarán normalmente.
                if (_nickname != null &&
                    nick.toLowerCase() == _nickname!.toLowerCase() &&
                    target.toLowerCase() == 'nick' &&
                    messageContent.toUpperCase().startsWith('IDENTIFY')) {
                  // debugLog('🔐 [IRCService] Ignorando PRIVMSG IDENTIFY que enviamos al bot \"nick\" (no debe aparecer en el chat)');
                  return;
                }

                // debugLog('🔍🔍🔍 [DEBUG PRIVMSG] PRIVMSG parsed: nick="$nick", target="$target", channelKey="$channelKey", message="$messageContent"');

                // Verificar si es nuestro propio mensaje (confirmación del servidor)
                // - Para mensajes de canal: el nick del remitente debe ser nuestro nick
                // - Para mensajes privados: también el nick del remitente debe ser nuestro nick
                //   (el target será el nick del otro usuario o servicio, p.ej. "nick")
                final isOurOwnMessage =
                    _nickname != null &&
                    nick.toLowerCase() == _nickname!.toLowerCase();

                // debugLog('🔍🔍🔍 [DEBUG PRIVMSG] Verificando si es nuestro mensaje:');
                // debugLog('  - nick del source: "$nick"');
                // debugLog('  - nuestro nickname: "$_nickname"');
                // debugLog('  - isChannel: $isChannel');
                // debugLog('  - Comparación: "${nick.toLowerCase()}" == "${_nickname?.toLowerCase()}" = $isOurOwnMessage');
                // debugLog('  - Mensaje recibido: "$messageContent"');
                // debugLog('  - Canal: "$channelKey"');

                if (isOurOwnMessage) {
                  // Es nuestro propio mensaje, verificar si hay un mensaje pendiente
                  // debugLog('✅✅✅ [DEBUG PRIVMSG] Mensaje propio detectado: "$messageContent" en canal "$channelKey"');

                  // Buscar mensaje pendiente que coincida
                  if (!channels.containsKey(channelKey)) {
                    // debugLog('❌❌❌ [DEBUG PRIVMSG] ERROR: Canal "$channelKey" no existe en channels!');
                    // debugLog('❌❌❌ [DEBUG PRIVMSG] Canales disponibles: ${channels.keys.toList()}');
                    return;
                  }

                  final channelObj = channels[channelKey]!;

                  // Buscar el mensaje pendiente más reciente que coincida
                  int pendingMsgIndex = -1;
                  IRCMessage? pendingMsg;

                  // Buscar desde el final (más reciente) hacia el principio
                  // debugLog('🔍🔍🔍 [DEBUG PRIVMSG] Buscando mensaje pendiente. Total mensajes: ${channelObj.messages.length}');
                  for (int i = channelObj.messages.length - 1; i >= 0; i--) {
                    final msg = channelObj.messages[i];
                    if (msg.isPending &&
                        msg.channel == channelKey &&
                        msg.nick == _nickname) {
                      // Verificar si el contenido coincide (exacto o similar)
                      final msgContent = msg.message.trim();
                      // Para mensajes ACTION, usar actionText en lugar de messageContent
                      final receivedContent = (isAction && actionText != null)
                          ? actionText.trim()
                          : messageContent.trim();
                      // También verificar si ambos son mensajes ACTION
                      if (msg.isAction == isAction) {
                        // debugLog('🔍 [IRCService] Comparando pendiente[$i]: "$msgContent" con recibido: "$receivedContent" (isAction: $isAction)');
                        if (_multilineMessagesMatch(
                          msgContent,
                          receivedContent,
                        )) {
                          pendingMsgIndex = i;
                          pendingMsg = msg;
                          // debugLog('✅ [IRCService] Mensaje pendiente encontrado en índice $i: "${msg.message}" (pendingId: ${msg.pendingId})');
                          break;
                        }
                      }
                    }
                  }

                  if (pendingMsgIndex == -1) {
                    // debugLog('⚠️  [IRCService] No se encontró mensaje pendiente. Listando todos los pendientes:');
                    for (int i = 0; i < channelObj.messages.length; i++) {
                      final msg = channelObj.messages[i];
                      if (msg.isPending &&
                          msg.channel == channelKey &&
                          msg.nick == _nickname) {
                        // debugLog('  - [$i] "${msg.message}" (pendingId: ${msg.pendingId})');
                      }
                    }
                  }

                  if (pendingMsgIndex != -1 && pendingMsg != null) {
                    // Verificar si el mensaje pendiente tiene un timer activo
                    final hasActiveTimer =
                        pendingMsg.pendingId != null &&
                        _pendingMessageTimers.containsKey(pendingMsg.pendingId);

                    if (hasActiveTimer) {
                      // El timer aún está activo, el mensaje aún no se ha enviado
                      // El servidor está respondiendo a un mensaje anterior o hay un problema
                      // debugLog('⏱️  [IRCService] Mensaje pendiente aún tiene timer activo (delay en curso), ignorando confirmación temprana del servidor');
                      return; // Ignorar la confirmación temprana del servidor
                    } else {
                      // El timer ya se ejecutó o no había timer (envío inmediato), confirmar el mensaje
                      // debugLog('✅ [IRCService] Timer ya ejecutado o sin delay, confirmando mensaje pendiente');
                      // Para mensajes ACTION, usar actionText en lugar de messageContent
                      final contentToConfirm = (isAction && actionText != null)
                          ? actionText
                          : messageContent;
                      final confirmed = confirmPendingMessage(
                        channelKey,
                        contentToConfirm,
                        DateTime.now(),
                      );
                      if (confirmed) {
                        // debugLog('✅ [IRCService] Mensaje pendiente confirmado, no se añadirá duplicado');
                        return; // Salir temprano para evitar añadir un mensaje duplicado
                      } else {
                        // debugLog('⚠️  [IRCService] No se pudo confirmar el mensaje pendiente, pero es nuestro mensaje, no añadir duplicado');
                        return; // No añadir duplicado aunque no se confirmó
                      }
                    }
                  } else {
                    // debugLog('⚠️  [IRCService] No se encontró mensaje pendiente para confirmar, puede ser un mensaje ya confirmado o de otro usuario');
                    // Si es nuestro mensaje pero no hay pendiente, no añadir duplicado
                    return; // No añadir duplicado
                  }
                } else {
                  // Es un mensaje de otro usuario, añadirlo normalmente

                  // Detectar marcador in-band de GIFT (\u200B GIFT data \u200B)
                  // También detectar sin \u200B (el servidor IRC puede strippearlos)
                  final cleanContent = messageContent.replaceAll('\u200B', '').trim();
                  final isGift = cleanContent.startsWith('GIFT ') &&
                      cleanContent.split('|').length >= 4;
                  debugLog('🎁 [GIFT-RECV] cleanContent="$cleanContent", isGift=$isGift');
                  if (isGift) {
                    debugLog('🎁 [GIFT-RECV] Detectado GIFT de $nick en $channelKey: $cleanContent');
                    // Reconstruir con \u200B para que chat_screen lo detecte
                    final giftMsg = IRCMessage(
                      nick: nick,
                      channel: channelKey,
                      message: '\u200B$cleanContent\u200B',
                      timestamp: DateTime.now(),
                      messageId: IRCMessage.generateMessageId(),
                    );
                    channels[channelKey]?.addMessage(giftMsg);
                    _notifyMessageListeners(giftMsg);
                    return; // No mostrar como texto visible
                  }

                  // Para mensajes ACTION, usar actionText en lugar de messageContent
                  final finalMessage = (isAction && actionText != null)
                      ? actionText
                      : messageContent;
                  final msg = IRCMessage(
                    nick: nick,
                    channel: channelKey,
                    message: finalMessage,
                    timestamp: DateTime.now(),
                    isAction: isAction,
                    messageId: IRCMessage.generateMessageId(),
                    replyToMessageId: extractedReplyToMessageId,
                  );

                  // debugLog('🔍 [DEBUG] ✅ Añadiendo mensaje al canal/query: $channelKey');
                  // debugLog('🔍 [DEBUG] ✅ Canal existe en mapa: ${channels.containsKey(channelKey)}');
                  channels[channelKey]!.addMessage(msg);
                  // debugLog('🔍 [DEBUG] ✅ Mensaje añadido. Total mensajes en canal: ${channels[channelKey]!.messages.length}');

                  // Guardar en historial local (no bloquear el hilo principal)
                  // Usamos el host actual como identificador de servidor
                  final serverId = _currentHost ?? 'unknown';
                  // Ignorar errores de forma silenciosa dentro del Future
                  // para no afectar al flujo de mensajes
                  // ignore: unawaited_futures
                  ChatHistoryService().saveMessage(
                    server: serverId,
                    message: msg,
                  );

                  // Notificar a los listeners de mensajes
                  _notifyMessageListeners(msg);
                }
                // debugLog('🔍 [DEBUG] ✅ Listeners notificados. Total listeners: ${_messageListeners.length}');

                // Si es un nuevo canal/query, notificar también a los listeners de lista de usuarios
                // para que el provider se actualice y muestre el nuevo canal en la UI
                if (isNewChannel) {
                  // debugLog('🔍 [DEBUG] 🔄 Nuevo canal/query creado, notificando userListListeners para actualizar UI');
                  _notifyUserListListeners(channelKey);
                }
              } else {
                // debugLog('🔍 [DEBUG] ⚠️  PRIVMSG: No colon found after target');
              }
            } else {
              // debugLog('🔍 [DEBUG] ⚠️  PRIVMSG: PRIVMSG keyword not found in line');
            }
          }
          break;

        case 'NOTICE':
          // Los NOTICE de NickServ / bot "nick" se procesan aquí
          if (args.isNotEmpty) {
            var target = args[0];
            final noticeIndex = line.indexOf('NOTICE');
            if (noticeIndex != -1) {
              final targetEndIndex =
                  line.indexOf(target, noticeIndex) + target.length;
              final colonIndex = line.indexOf(':', targetEndIndex);

              if (colonIndex != -1) {
                final messageContent = line.substring(colonIndex + 1).trim();

                // 1) Verificar si es una respuesta de STATUS de NickServ/nick
                // El formato puede ser: STATUS Fran 3 Fran (con el nick repetido al final)
                if ((nick.toLowerCase() == 'nickserv' ||
                        nick.toLowerCase() == 'nick') &&
                    messageContent.contains('STATUS')) {
                  // Buscar el patrón STATUS nick número (puede tener el nick repetido al final)
                  final match = RegExp(
                    r'STATUS\s+(\S+)\s+(\d+)',
                  ).firstMatch(messageContent);
                  if (match != null) {
                    final checkedNick = match.group(1)!.toLowerCase();
                    final status = int.tryParse(match.group(2)!);
                    // debugLog('📋 [IRCService] Status recibido (NOTICE) para nick "$checkedNick": $status');
                    // debugLog('📋 [IRCService] Mensaje completo: $messageContent');
                    final completer = _statusCheckCompleters.remove(
                      checkedNick,
                    );
                    if (completer != null && !completer.isCompleted) {
                      completer.complete(status);
                      // debugLog('✅ [IRCService] Completer completado con status: $status');
                    } else if (completer != null && completer.isCompleted) {
                      // debugLog('⚠️  [IRCService] Completer ya estaba completado para nick: $checkedNick');
                    } else {
                      // debugLog('⚠️  [IRCService] No se encontró completer para nick: $checkedNick');
                    }
                    // No procesar como mensaje normal si es una respuesta de STATUS
                    break;
                  }
                }

                // 2) Capturar NOTICE relacionados con comandos IRCop (como REHASH)
                if (_currentIRCOpCommand != null) {
                  // Verificar si el mensaje está dirigido a nosotros o es un mensaje del servidor
                  final cleanTarget = target.trim();
                  final cleanNickname = _nickname?.trim();
                  final isToUs =
                      cleanNickname != null &&
                      cleanTarget.toLowerCase() == cleanNickname.toLowerCase();
                  final isFromServer =
                      nick.contains('.') ||
                      nick == 'GlobalChat' ||
                      nick.toLowerCase().contains('server') ||
                      messageContent.toLowerCase().contains('rehash') ||
                      messageContent.toLowerCase().contains('reload');

                  if (isToUs || isFromServer) {
                    _ircopCommandResults.add(messageContent);
                    // debugLog('📋 [IRCOp] NOTICE capturado para $_currentIRCOpCommand: $messageContent');
                    // Si el mensaje indica que el comando terminó, finalizar inmediatamente
                    if (messageContent.toLowerCase().contains('completed') ||
                        messageContent.toLowerCase().contains('error') ||
                        messageContent.toLowerCase().contains('failed')) {
                      _ircopCommandTimer?.cancel();
                      _notifyIRCOpCommandListeners(_ircopCommandResults);
                      // debugLog('📋 [IRCOp] Fin de $_currentIRCOpCommand (completado)');
                      _ircopCommandResults.clear();
                      _currentIRCOpCommand = null;
                      _ircopCommandTimer = null;
                    }
                    // No procesar como mensaje normal si es parte de un comando IRCop
                    break;
                  }
                }

                // 2.5) No mostrar NOTICE de StatServ ni Global en la ventana de chat (ocultar como servicios)
                final noticeSenderLower = nick.toLowerCase();
                if (noticeSenderLower == 'statserv' ||
                    noticeSenderLower == 'global') {
                  break;
                }

                // 3) Verificar si es un NOTICE privado de un usuario ignorado
                final cleanTarget = target.trim();
                final cleanNickname = _nickname?.trim();
                final isPrivateNoticeToUs =
                    cleanNickname != null &&
                    !target.startsWith('#') &&
                    cleanTarget.toLowerCase() == cleanNickname.toLowerCase();

                if (isPrivateNoticeToUs) {
                  // Es un NOTICE privado dirigido a nosotros
                  final senderNick = nick.toLowerCase();
                  if (_ignoredUsers.contains(senderNick)) {
                    // Usuario ignorado: bloquear el NOTICE
                    // No enviar respuesta automática para NOTICE (solo para PRIVMSG)
                    break; // Ignorar el NOTICE completamente
                  }
                }

                // 4) Si es un NOTICE del bot "nick" dirigido a nosotros,
                // mostrarlo en el query privado "nick"
                if (nick.toLowerCase() == 'nick' &&
                    cleanNickname != null &&
                    cleanTarget.toLowerCase() == cleanNickname.toLowerCase()) {
                  const channelKey = 'nick'; // nombre del query en la UI
                  if (!channels.containsKey(channelKey)) {
                    channels[channelKey] = IRCChannel(name: channelKey);
                  }
                  final msg = IRCMessage(
                    nick: 'nick',
                    channel: channelKey,
                    message: messageContent,
                    timestamp: DateTime.now(),
                  );
                  channels[channelKey]!.addMessage(msg);
                  _notifyMessageListeners(msg);
                  // debugLog('📥 [IRCService] NOTICE del bot "nick" añadido al query: "$messageContent"');
                } else {
                  // 5) Procesar NOTICE de otros usuarios (similar a PRIVMSG)

                  // Filtrar mensajes del sistema del servidor (hostname con puntos)
                  final isServerMessage =
                      nick.contains('.') &&
                      (nick.split('.').length >
                              2 || // Múltiples puntos (ej: ceres.globalchat.org)
                          RegExp(
                            r'\.(org|com|net|edu|gov|io|co|uk|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|pl|cz|sk|hu|ro|bg|gr|pt|ie|lu|mt|cy|ee|lv|lt|si|hr|rs|ba|mk|al|me|is|li|ad|mc|sm|va|by|ua|md|ge|am|az|kz|uz|tm|tj|kg|mn|cn|jp|kr|in|au|nz|za|br|mx|ar|cl|co|pe|ve|ec|uy|py|bo|cr|pa|do|gt|hn|ni|sv|bz|jm|tt|bb|gd|lc|vc|ag|bs|dm|kn|sr|gy|fk|ai|vg|ky|bm|tc|ms|pw|fm|mh|nr|ki|tv|to|ws|sb|vu|nc|pf|as|gu|mp|pr|vi|um|us|ca)$',
                            caseSensitive: false,
                          ).hasMatch(nick));

                  // Filtrar mensajes del sistema que empiezan con ***
                  final isSystemMessage = messageContent.trim().startsWith(
                    '***',
                  );

                  // No mostrar NOTICE del servidor o mensajes del sistema
                  if (isServerMessage || isSystemMessage) {
                    // debugLog('🚫 [IRCService] NOTICE del sistema ignorado: $nick -> $messageContent');
                    break;
                  }

                  // Detectar CTCP TYPING en NOTICE (raw bytes, texto generado por servidor, o formato -CTCP-)
                  if (messageContent.contains('\x01TYPING') ||
                      RegExp(r'CTCP\s+TYPING|TYPING\s+\d?', caseSensitive: false)
                          .hasMatch(messageContent)) {
                    break;
                  }

                  // Detectar CTCP PING (poke/zumbido) en NOTICE
                  if (messageContent.startsWith('\x01PING') &&
                      messageContent.endsWith('\x01') &&
                      nick.toLowerCase() != _nickname?.toLowerCase()) {
                    _notifyPokeListeners(nick);
                    break;
                  }

                  // Detectar y procesar mensajes ACTION (/me) en NOTICE
                  bool isAction = false;
                  String? actionText;
                  String finalMessage = messageContent;
                  if (messageContent.startsWith('\x01ACTION ') &&
                      messageContent.endsWith('\x01')) {
                    isAction = true;
                    // Extraer el texto de la acción (sin \x01ACTION y sin el \x01 final)
                    actionText = messageContent
                        .substring(8, messageContent.length - 1)
                        .trim();
                    finalMessage =
                        actionText; // Usar el texto de la acción como mensaje
                    // debugLog('🎭 [IRCService] Mensaje ACTION detectado en NOTICE: "$actionText"');
                  }

                  // Determinar si es un canal (#) o un mensaje privado (nick)
                  bool isChannel = target.startsWith('#');
                  String channelKey;

                  if (isChannel) {
                    // Es un NOTICE a un canal
                    channelKey = _normalizeChannelName(target);
                  } else {
                    // Es un NOTICE privado
                    final cleanNickname = _nickname?.trim();
                    if (cleanNickname != null &&
                        cleanTarget.toLowerCase() ==
                            cleanNickname.toLowerCase()) {
                      // NOTICE privado que nos envían, usar el nick del remitente
                      channelKey = nick.toLowerCase();
                    } else {
                      // NOTICE privado que enviamos, usar el target
                      channelKey = cleanTarget.toLowerCase();
                    }
                  }

                  // Crear el canal/query si no existe
                  if (!channels.containsKey(channelKey)) {
                    channels[channelKey] = IRCChannel(name: channelKey);
                  }

                  // Verificar si es nuestro propio mensaje (confirmación del servidor)
                  final isOurOwnMessage =
                      _nickname != null &&
                      nick.toLowerCase() == _nickname!.toLowerCase();

                  if (isOurOwnMessage && isAction) {
                    // Es nuestro propio mensaje ACTION, buscar mensaje pendiente
                    final channelObj = channels[channelKey]!;
                    int pendingMsgIndex = -1;
                    IRCMessage? pendingMsg;

                    // Buscar desde el final (más reciente) hacia el principio
                    for (int i = channelObj.messages.length - 1; i >= 0; i--) {
                      final msg = channelObj.messages[i];
                      if (msg.isPending &&
                          msg.channel == channelKey &&
                          msg.nick == _nickname &&
                          msg.isAction == true) {
                        final msgContent = msg.message.trim();
                        final receivedContent = actionText?.trim() ?? '';
                        if (_multilineMessagesMatch(
                          msgContent,
                          receivedContent,
                        )) {
                          pendingMsgIndex = i;
                          pendingMsg = msg;
                          break;
                        }
                      }
                    }

                    if (pendingMsgIndex != -1 && pendingMsg != null) {
                      // Confirmar el mensaje pendiente
                      final confirmed = confirmPendingMessage(
                        channelKey,
                        actionText ?? messageContent,
                        DateTime.now(),
                      );
                      if (confirmed) {
                        return; // No añadir duplicado
                      }
                    }
                    // Si no se encontró pendiente, no añadir duplicado de todas formas
                    return;
                  }

                  // Crear el mensaje NOTICE (puede ser ACTION)
                  final msg = IRCMessage(
                    nick: nick,
                    channel: channelKey,
                    message: finalMessage,
                    timestamp: DateTime.now(),
                    isAction: isAction,
                    messageId: IRCMessage.generateMessageId(),
                  );

                  channels[channelKey]!.addMessage(msg);
                  _notifyMessageListeners(msg);
                  // debugLog('📢 [IRCService] NOTICE añadido: $nick -> $channelKey: $messageContent (isAction: $isAction)');
                }
              }
            }
          }
          break;

        case 'QUIT':
          // User quit from all channels
          final affectedChannels = <String>[];
          for (var entry in channels.entries) {
            if (entry.value.users.contains(nick)) {
              entry.value.removeUser(nick);
              affectedChannels.add(entry.key);

              // Crear mensaje de sistema para cada canal
              final msg = IRCMessage(
                nick: nick,
                channel: entry.key,
                message: '✕ salió del canal (desconectado)',
                timestamp: DateTime.now(),
                isSystem: true,
              );
              entry.value.addMessage(msg);
              _notifyMessageListeners(msg);
            }
          }
          // Notificar cambios en la lista de usuarios para cada canal afectado
          for (var channel in affectedChannels) {
            _notifyUserListListeners(channel);
          }
          break;

        case 'TOPIC':
          // :nick!user@host TOPIC #channel :new topic
          if (args.isNotEmpty && args[0].startsWith('#')) {
            final channelKey = _normalizeChannelName(args[0]);
            final colonIdx = line.indexOf(':', line.indexOf('TOPIC'));
            final topicText = colonIdx != -1 && colonIdx < line.length - 1
                ? IRCColorParser.stripIRCFormatting(line.substring(colonIdx + 1).trim())
                : '';

            if (channels.containsKey(channelKey)) {
              channels[channelKey]!.setTopic(topicText);
              _notifyTopicListeners(channelKey);

              // Agregar mensaje de sistema al canal
              final topicMsg = IRCMessage(
                nick: nick ?? '',
                channel: channelKey,
                message: 'Topic: $topicText',
                timestamp: DateTime.now(),
                isSystem: true,
                messageId: IRCMessage.generateMessageId(),
              );
              channels[channelKey]!.addMessage(topicMsg);
              _notifyMessageListeners(topicMsg);
            }
          }
          break;
      }
    } catch (e) {
      // debugLog('Error parsing IRC message: $e');
    }
  }

  void _onDisconnect({
    bool scheduleReconnect = true,
    String reason = 'socket_closed',
  }) {
    if (!_isConnected &&
        _connection == null &&
        !_hasActiveConnection &&
        !scheduleReconnect) {
      return;
    }

    _stopLagPingTimer();
    _stopHeartbeatWatchdog();
    _stopExpiredMessagesTimer();
    _stopAwayStatusUpdateTimer();
    _isConnected = false;
    _isRegistered = false;
    if (!_connectionCompleter.isCompleted) {
      _connectionCompleter.completeError(
        StateError('Conexión cerrada antes del registro IRC ($reason)'),
      );
    }
    // Resetear el lag al desconectar
    _notifyLagListeners(0); // Notificar lag 0 para resetear
    channels.clear();
    _pendingJoinChannels.clear();
    _currentChannel = null;
    _connection = null;
    _currentHost = null;
    _lastServerActivityAt = null;
    _lastWhoisCheck.clear(); // Limpiar timestamps de verificación
    for (var listener in _disconnectionListeners) {
      listener();
    }

    if (scheduleReconnect && !_manualDisconnectRequested) {
      _scheduleReconnect(reason: reason);
    }
  }

  void addMessageListener(Function(IRCMessage) listener) {
    _messageListeners.add(listener);
  }

  void removeMessageListener(Function(IRCMessage) listener) {
    _messageListeners.remove(listener);
  }

  void addPendingRemovalListener(Function(String channel, String pendingId) listener) {
    _pendingRemovalListeners.add(listener);
  }

  void removePendingRemovalListener(Function(String channel, String pendingId) listener) {
    _pendingRemovalListeners.remove(listener);
  }

  void addUserListListener(Function(String) listener) {
    _userListListeners.add(listener);
  }

  void removeUserListListener(Function(String) listener) {
    _userListListeners.remove(listener);
  }

  void addConnectionListener(Function() listener) {
    _connectionListeners.add(listener);
  }

  void addDisconnectionListener(Function() listener) {
    _disconnectionListeners.add(listener);
  }

  void addTopicListener(Function(String) listener) {
    _topicListeners.add(listener);
  }

  void removeTopicListener(Function(String) listener) {
    _topicListeners.remove(listener);
  }

  void addNickChangeListener(Function(String) listener) {
    _nickChangeListeners.add(listener);
  }

  void removeNickChangeListener(Function(String) listener) {
    _nickChangeListeners.remove(listener);
  }

  void addKickListener(Function(String, String) listener) {
    _kickListeners.add(listener);
  }

  void removeKickListener(Function(String, String) listener) {
    _kickListeners.remove(listener);
  }

  void addJoinFailListener(
    void Function(String channel, String reason, int code) listener,
  ) {
    _joinFailListeners.add(listener);
  }

  void removeJoinFailListener(
    void Function(String channel, String reason, int code) listener,
  ) {
    _joinFailListeners.remove(listener);
  }

  bool _channelJoinConfirmed(String normalized) {
    return _serverConfirmedChannels.contains(normalized) ||
        _isListedInChannelUsers(normalized);
  }

  void addWhoisListener(Function(WhoisInfo) listener) {
    _whoisListeners.add(listener);
  }

  void removeWhoisListener(Function(WhoisInfo) listener) {
    _whoisListeners.remove(listener);
  }

  void addIRCOpListener(Function() listener) {
    _ircopListeners.add(listener);
  }

  void removeIRCOpListener(Function() listener) {
    _ircopListeners.remove(listener);
  }

  WhoisInfo? getWhoisInfo(String nick) {
    return _whoisCache[nick.toLowerCase()];
  }

  void _notifyWhoisListeners(WhoisInfo info) {
    for (var listener in _whoisListeners) {
      listener(info);
    }
  }

  // Listeners para LIST
  void addListListener(Function(List<Map<String, dynamic>>) listener) {
    _listListeners.add(listener);
  }

  void removeListListener(Function(List<Map<String, dynamic>>) listener) {
    _listListeners.remove(listener);
  }

  void _notifyListListeners(List<Map<String, dynamic>> results) {
    for (var listener in _listListeners) {
      listener(results);
    }
  }

  // Listeners para WHO
  void addWhoListener(Function(List<Map<String, dynamic>>) listener) {
    _whoListeners.add(listener);
  }

  void removeWhoListener(Function(List<Map<String, dynamic>>) listener) {
    _whoListeners.remove(listener);
  }

  void _notifyWhoListeners(List<Map<String, dynamic>> results) {
    for (var listener in _whoListeners) {
      listener(results);
    }
  }

  // Listeners para comandos IRCop
  void addIRCOpCommandListener(Function(List<String>) listener) {
    _ircopCommandListeners.add(listener);
  }

  void removeIRCOpCommandListener(Function(List<String>) listener) {
    _ircopCommandListeners.remove(listener);
  }

  void _notifyIRCOpCommandListeners(List<String> results) {
    for (var listener in _ircopCommandListeners) {
      listener(results);
    }
  }

  void addLagListener(Function(int) listener) {
    _lagListeners.add(listener);
  }

  void removeLagListener(Function(int) listener) {
    _lagListeners.remove(listener);
  }

  void _notifyLagListeners(int lagMs) {
    for (var listener in _lagListeners) {
      try {
        listener(lagMs);
      } catch (e) {
        // debugLog('❌ Error notificando lag listener: $e');
      }
    }
  }

  void _startLagPingTimer() {
    _lagPingTimer?.cancel();

    // Enviar un PING inmediatamente al conectar
    if (_isConnected && _hasActiveConnection) {
      _lastPingToken = DateTime.now().millisecondsSinceEpoch.toString();
      _lastPingSent = DateTime.now();
      _sendCommand('PING $_lastPingToken');
      // debugLog('📊 [IRCService] Enviando PING inicial para medir lag: $_lastPingToken');
    }

    // Enviar PING cada cierto tiempo para mantener viva la sesión sin castigar
    // navegadores con suspensión agresiva de timers, como Chromebook/ChromeOS.
    _lagPingTimer = Timer.periodic(_lagPingInterval, (timer) {
      if (_isConnected && _hasActiveConnection) {
        // Solo enviar si no hay un PING pendiente desde hace demasiado tiempo.
        if (_lastPingSent == null ||
            DateTime.now().difference(_lastPingSent!) > _resumeProbeTimeout) {
          // Generar un token único para este PING
          _lastPingToken = DateTime.now().millisecondsSinceEpoch.toString();
          _lastPingSent = DateTime.now();
          _sendCommand('PING $_lastPingToken');
          // debugLog('📊 [IRCService] Enviando PING para medir lag: $_lastPingToken');
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _stopLagPingTimer() {
    _lagPingTimer?.cancel();
    _lagPingTimer = null;
    _lastPingSent = null;
    _lastPingToken = null;
  }

  void _startExpiredMessagesTimer() {
    _expiredMessagesTimer?.cancel();

    // Verificar mensajes expirados cada 10 segundos
    _expiredMessagesTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) {
      if (_isConnected) {
        _checkExpiredMessages();
      } else {
        timer.cancel();
      }
    });
  }

  void _stopExpiredMessagesTimer() {
    _expiredMessagesTimer?.cancel();
    _expiredMessagesTimer = null;
  }

  void _startAwayStatusUpdateTimer() {
    _awayStatusUpdateTimer?.cancel();

    // Actualizar estado away cada 2 minutos para usuarios en canales activos
    _awayStatusUpdateTimer = Timer.periodic(const Duration(minutes: 2), (
      timer,
    ) {
      if (_isConnected && _hasActiveConnection) {
        _updateAwayStatusForActiveUsers();
      } else {
        timer.cancel();
      }
    });
  }

  void _stopAwayStatusUpdateTimer() {
    _awayStatusUpdateTimer?.cancel();
    _awayStatusUpdateTimer = null;
    _lastWhoisCheck.clear();
  }

  void _updateAwayStatusForActiveUsers() {
    if (!_isConnected || !_hasActiveConnection) return;

    final now = DateTime.now();
    final Set<String> usersToCheck = {};

    // Recopilar usuarios de todos los canales activos
    for (var channelEntry in channels.entries) {
      final channel = channelEntry.value;
      for (var user in channel.users) {
        // No hacer WHOIS de nosotros mismos
        if (_nickname != null &&
            user.toLowerCase() == _nickname!.toLowerCase()) {
          continue;
        }

        // Solo verificar usuarios válidos (no servidores/hosts)
        final isServerHost =
            user.contains('.') &&
            (user.split('.').length > 2 ||
                RegExp(
                  r'\.(org|com|net|edu|gov|io|co|uk|de|fr|es|it|nl|be|ch|at|se|no|dk|fi|pl|cz|sk|hu|ro|bg|gr|pt|ie|lu|mt|cy|ee|lv|lt|si|hr|rs|ba|mk|al|me|is|li|ad|mc|sm|va|by|ua|md|ge|am|az|kz|uz|tm|tj|kg|mn|cn|jp|kr|in|au|nz|za|br|mx|ar|cl|co|pe|ve|ec|uy|py|bo|cr|pa|do|gt|hn|ni|sv|bz|jm|tt|bb|gd|lc|vc|ag|bs|dm|kn|sr|gy|fk|ai|vg|ky|bm|tc|ms|pw|fm|mh|nr|ki|tv|to|ws|sb|vu|nc|pf|as|gu|mp|pr|vi|um|us|ca)$',
                  caseSensitive: false,
                ).hasMatch(user));

        if (!isServerHost) {
          final userLower = user.toLowerCase();
          final lastCheck = _lastWhoisCheck[userLower];

          // Solo hacer WHOIS si:
          // 1. Nunca se ha hecho WHOIS para este usuario, O
          // 2. La última verificación fue hace más de 2 minutos, O
          // 3. No tenemos información en caché o es antigua (más de 5 minutos)
          final cachedInfo = _whoisCache[userLower];
          final shouldCheck =
              lastCheck == null ||
              now.difference(lastCheck) > const Duration(minutes: 2) ||
              cachedInfo == null ||
              (cachedInfo.signonTime != null &&
                  now.difference(cachedInfo.signonTime!) >
                      const Duration(minutes: 5));

          if (shouldCheck) {
            usersToCheck.add(user);
          }
        }
      }
    }

    // Hacer WHOIS para los usuarios seleccionados, con un pequeño delay entre cada uno para evitar spam
    int delay = 0;
    for (var user in usersToCheck) {
      Future.delayed(Duration(milliseconds: delay), () {
        if (_isConnected && _hasActiveConnection) {
          _lastWhoisCheck[user.toLowerCase()] = DateTime.now();
          sendWhois(user);
        }
      });
      delay += 500; // 500ms entre cada WHOIS
    }
  }

  void _notifyMessageListeners(IRCMessage message) {
    for (var listener in _messageListeners) {
      listener(message);
    }
  }

  void _notifyUserListListeners(String channel) {
    // debugLog('🔔 _notifyUserListListeners: channel=$channel, listeners=${_userListListeners.length}');
    for (var listener in _userListListeners) {
      listener(channel);
    }
  }

  void _notifyTopicListeners(String channel) {
    // debugLog('🔔 _notifyTopicListeners: channel=$channel, listeners=${_topicListeners.length}');
    for (var listener in _topicListeners) {
      listener(channel);
    }
  }

  // Editar un mensaje propio
  bool editMessage(String channel, String messageId, String newMessage) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;

    final channelObj = channels[normalized]!;
    final messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId && msg.nick == _nickname,
    );

    if (messageIndex == -1) return false;

    final oldMessage = channelObj.messages[messageIndex];

    // Si el mensaje está pendiente, actualizar el mensaje que se enviará
    if (oldMessage.isPending && oldMessage.pendingId != null) {
      final pendingId = oldMessage.pendingId!;

      // Verificar si el mensaje ya fue enviado (timer ya ejecutado o fue forzado)
      final hasActiveTimer = _pendingMessageTimers.containsKey(pendingId);

      // Cancelar el timer anterior si existe
      final oldTimer = _pendingMessageTimers.remove(pendingId);
      if (oldTimer != null) {
        oldTimer.cancel();
        // debugLog('⏱️  [IRCService] Timer cancelado para editar mensaje pendiente: $pendingId');
      }

      // Actualizar el mensaje pendiente con el nuevo contenido
      // IMPORTANTE: Si el mensaje ya fue enviado (fuerza envío), eliminar el delaySeconds
      // para que no se cree un nuevo timer cuando se edite
      final updatedMessage = oldMessage.copyWith(
        message: newMessage,
        isEdited: true,
        editedAt: DateTime.now(),
        delaySeconds: hasActiveTimer
            ? oldMessage.delaySeconds
            : null, // Si ya fue enviado, quitar delay
      );
      channelObj.messages[messageIndex] = updatedMessage;
      _notifyMessageListeners(updatedMessage);

      // Si el mensaje ya fue enviado (no tenía timer activo), enviar el nuevo contenido inmediatamente
      // Esto ocurre cuando se fuerza el envío y luego se edita
      if (!hasActiveTimer) {
        // El mensaje ya fue enviado, pero ahora tiene contenido nuevo, enviarlo inmediatamente
        // debugLog('📤 [IRCService] Mensaje ya fue enviado (fuerza envío), enviando contenido editado inmediatamente');
        _sendWirePrivmsg(normalized, newMessage);
        // debugLog('✅ [IRCService] Mensaje editado enviado inmediatamente (mensaje ya estaba enviado)');

        // Auto-confirmar después de 500ms si el servidor no hace eco
        Timer(const Duration(milliseconds: 500), () {
          final channelObj = channels[normalized];
          if (channelObj != null) {
            final currentPendingMessages = channelObj.messages
                .where((m) => m.isPending && m.pendingId == pendingId)
                .toList();
            if (currentPendingMessages.isNotEmpty) {
              // debugLog('⚠️  [IRCService] Mensaje editado (forzado) $pendingId aún pendiente después de 500ms, auto-confirmando.');
              confirmPendingMessage(normalized, newMessage, DateTime.now());
            }
          }
        });
      } else {
        // El mensaje aún tiene timer activo, crear un nuevo timer con el contenido editado
        // Si hay un delay configurado, crear un nuevo timer con el mensaje actualizado
        if (updatedMessage.delaySeconds != null &&
            updatedMessage.delaySeconds! > 0) {
          final delaySeconds = updatedMessage.delaySeconds!;
          // debugLog('⏱️  [IRCService] Programando envío de mensaje editado $pendingId en ${delaySeconds}s');
          final timer = Timer(Duration(seconds: delaySeconds), () {
            // debugLog('⏱️  [IRCService] Timer ejecutado, enviando mensaje editado $pendingId');
            _sendWirePrivmsg(normalized, newMessage);
            // debugLog('📤 [IRCService] Mensaje editado enviado al servidor después de delay: $pendingId');
            _pendingMessageTimers.remove(pendingId);

            // Auto-confirmar después de 500ms si el servidor no hace eco
            Timer(const Duration(milliseconds: 500), () {
              final channelObj = channels[normalized];
              if (channelObj != null) {
                final currentPendingMessages = channelObj.messages
                    .where((m) => m.isPending && m.pendingId == pendingId)
                    .toList();
                if (currentPendingMessages.isNotEmpty) {
                  // debugLog('⚠️  [IRCService] Mensaje editado con delay $pendingId aún pendiente después de 500ms, auto-confirmando.');
                  confirmPendingMessage(normalized, newMessage, DateTime.now());
                }
              }
            });
          });
          _pendingMessageTimers[pendingId] = timer;
          // debugLog('✅ [IRCService] Timer creado para mensaje editado, se enviará en ${delaySeconds}s');
        } else {
          // Sin delay, enviar inmediatamente
          // debugLog('📤 [IRCService] Enviando mensaje editado inmediatamente (sin delay)');
          _sendWirePrivmsg(normalized, newMessage);
          // debugLog('✅ [IRCService] Mensaje editado enviado inmediatamente');

          // Auto-confirmar después de 500ms si el servidor no hace eco
          Timer(const Duration(milliseconds: 500), () {
            if (!_shouldAutoConfirmPending(newMessage)) return;
            final channelObj = channels[normalized];
            if (channelObj != null) {
              final currentPendingMessages = channelObj.messages
                  .where((m) => m.isPending && m.pendingId == pendingId)
                  .toList();
              if (currentPendingMessages.isNotEmpty) {
                // debugLog('⚠️  [IRCService] Mensaje editado sin delay $pendingId aún pendiente después de 500ms, auto-confirmando.');
                confirmPendingMessage(normalized, newMessage, DateTime.now());
              }
            }
          });
        }
      }

      // debugLog('✏️  [IRCService] Mensaje pendiente editado: $messageId en $normalized');
      return true;
    } else {
      // Mensaje ya enviado, solo actualizar el contenido localmente
      final updatedMessage = oldMessage.copyWith(
        message: newMessage,
        isEdited: true,
        editedAt: DateTime.now(),
      );

      channelObj.messages[messageIndex] = updatedMessage;
      _notifyMessageListeners(updatedMessage);

      // Enviar comando de edición al servidor (si el servidor lo soporta)
      // Nota: IRC no tiene un comando estándar para editar mensajes
      // Esto es una funcionalidad del cliente
      // debugLog('✏️  [IRCService] Mensaje confirmado editado: $messageId en $normalized');
      return true;
    }
  }

  // Añadir o quitar una reacción a un mensaje
  bool toggleReaction(String channel, String messageId, String emoji) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;

    final channelObj = channels[normalized]!;
    int messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );

    // Si no se encuentra por messageId, buscar el último mensaje sin messageId
    // Esto es para mensajes antiguos que no tienen messageId
    if (messageIndex == -1) {
      // Buscar desde el final hacia atrás el primer mensaje sin messageId
      for (int i = channelObj.messages.length - 1; i >= 0; i--) {
        final msg = channelObj.messages[i];
        if (msg.messageId == null) {
          // Asignar el messageId al mensaje encontrado
          final updatedMsg = msg.copyWith(messageId: messageId);
          channelObj.messages[i] = updatedMsg;
          messageIndex = i;
          break;
        }
      }
    }

    if (messageIndex == -1) return false;

    final oldMessage = channelObj.messages[messageIndex];
    final currentReactions = Map<String, int>.from(oldMessage.reactions);

    // Toggle: si existe, incrementar; si no, añadir con 1
    if (currentReactions.containsKey(emoji)) {
      currentReactions[emoji] = (currentReactions[emoji] ?? 0) + 1;
    } else {
      currentReactions[emoji] = 1;
    }

    // Asegurar que el mensaje tenga el messageId correcto
    final finalMessageId = oldMessage.messageId ?? messageId;

    final updatedMessage = oldMessage.copyWith(
      reactions: currentReactions,
      messageId: finalMessageId,
    );
    channelObj.messages[messageIndex] = updatedMessage;
    _notifyMessageListeners(updatedMessage);

    // Enviar la reacción al servidor para sincronización entre usuarios
    // Formato: /me +emoji [messageId]
    if (_hasActiveConnection && _nickname != null) {
      final reactionCommand = '+$emoji [$finalMessageId]';
      _sendCommand('PRIVMSG $normalized :\x01ACTION $reactionCommand\x01');
    }

    // debugLog('👍 [IRCService] Reacción añadida: $emoji a mensaje $messageId');
    return true;
  }

  // Aplicar una reacción recibida del servidor (de otro usuario)
  void _applyReactionFromServer(
    String channel,
    String messageId,
    String emoji,
    String reactorNick,
  ) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return;

    final channelObj = channels[normalized]!;
    int messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );

    // Si no se encuentra por messageId, buscar mensajes sin messageId (para compatibilidad)
    if (messageIndex == -1) {
      // Buscar desde el final hacia atrás el primer mensaje sin messageId
      for (int i = channelObj.messages.length - 1; i >= 0; i--) {
        final msg = channelObj.messages[i];
        if (msg.messageId == null) {
          // Asignar el messageId al mensaje encontrado
          final updatedMsg = msg.copyWith(messageId: messageId);
          channelObj.messages[i] = updatedMsg;
          messageIndex = i;
          break;
        }
      }
    }

    if (messageIndex == -1) return;

    final oldMessage = channelObj.messages[messageIndex];
    final currentReactions = Map<String, int>.from(oldMessage.reactions);

    // Incrementar la reacción (o añadir con 1 si no existe)
    if (currentReactions.containsKey(emoji)) {
      currentReactions[emoji] = (currentReactions[emoji] ?? 0) + 1;
    } else {
      currentReactions[emoji] = 1;
    }

    // Asegurar que el mensaje tenga el messageId correcto
    final finalMessageId = oldMessage.messageId ?? messageId;

    final updatedMessage = oldMessage.copyWith(
      reactions: currentReactions,
      messageId: finalMessageId,
    );
    channelObj.messages[messageIndex] = updatedMessage;
    _notifyMessageListeners(updatedMessage);

    // debugLog('👍 [IRCService] Reacción recibida de $reactorNick: $emoji a mensaje $messageId');
  }

  // Responder a un mensaje específico
  void replyToMessage(
    String channel,
    String replyToMessageId,
    String message, {
    int delaySeconds = 0,
  }) {
    final normalized = _normalizeChannelName(channel);

    // Enviar el mensaje directamente con la referencia al mensaje original
    sendMessage(
      normalized,
      message,
      delaySeconds: delaySeconds,
      replyToMessageId: replyToMessageId,
    );

    // debugLog('💬 [IRCService] Respondiendo a mensaje $replyToMessageId en $normalized');
  }

  // Obtener un mensaje por su ID
  IRCMessage? getMessageById(String channel, String messageId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return null;

    try {
      return channels[normalized]!.messages.firstWhere(
        (msg) => msg.messageId == messageId,
      );
    } catch (e) {
      return null;
    }
  }

  // Contar cuántas respuestas tiene un mensaje
  int getReplyCount(String channel, String messageId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return 0;

    return channels[normalized]!.messages
        .where((msg) => msg.replyToMessageId == messageId)
        .length;
  }

  // Obtener todas las respuestas a un mensaje
  List<IRCMessage> getReplies(String channel, String messageId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return [];

    return channels[normalized]!.messages
        .where((msg) => msg.replyToMessageId == messageId)
        .toList();
  }

  // Fijar un mensaje en un canal
  bool pinMessage(String channel, String messageId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;
    if (_nickname == null) return false;

    final channelObj = channels[normalized]!;
    int messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );

    // Si no se encuentra por messageId, buscar el último mensaje sin messageId
    // Esto es para mensajes antiguos que no tienen messageId
    if (messageIndex == -1) {
      // Buscar desde el final hacia atrás el primer mensaje sin messageId
      for (int i = channelObj.messages.length - 1; i >= 0; i--) {
        final msg = channelObj.messages[i];
        if (msg.messageId == null) {
          // Asignar el messageId al mensaje encontrado
          final updatedMsg = msg.copyWith(messageId: messageId);
          channelObj.messages[i] = updatedMsg;
          messageIndex = i;
          break;
        }
      }
    }

    if (messageIndex == -1) return false;

    final message = channelObj.messages[messageIndex];

    // Si ya está fijado, no hacer nada
    if (message.isPinned) return true;

    // Asegurar que el mensaje tenga el messageId correcto
    final finalMessageId = message.messageId ?? messageId;

    // Actualizar el mensaje
    final updatedMessage = message.copyWith(
      isPinned: true,
      pinnedAt: DateTime.now(),
      pinnedBy: _nickname,
      messageId: finalMessageId,
    );
    channelObj.messages[messageIndex] = updatedMessage;

    // Añadir a la lista de mensajes fijados del canal
    if (!channelObj.pinnedMessageIds.contains(finalMessageId)) {
      channelObj.pinnedMessageIds.add(finalMessageId);
    }

    _notifyMessageListeners(updatedMessage);
    _notifyUserListListeners(normalized); // Notificar para actualizar UI

    return true;
  }

  // Desfijar un mensaje
  bool unpinMessage(String channel, String messageId) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;

    final channelObj = channels[normalized]!;
    final messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );

    if (messageIndex == -1) return false;

    final message = channelObj.messages[messageIndex];

    // Si no está fijado, no hacer nada
    if (!message.isPinned) return true;

    // Actualizar el mensaje
    final updatedMessage = message.copyWith(
      isPinned: false,
      pinnedAt: null,
      pinnedBy: null,
    );
    channelObj.messages[messageIndex] = updatedMessage;

    // Remover de la lista de mensajes fijados
    channelObj.pinnedMessageIds.remove(messageId);

    _notifyMessageListeners(updatedMessage);
    _notifyUserListListeners(normalized); // Notificar para actualizar UI

    return true;
  }

  // Obtener mensajes fijados de un canal
  List<IRCMessage> getPinnedMessages(String channel) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return [];

    final channelObj = channels[normalized]!;
    return channelObj.messages
        .where(
          (msg) =>
              msg.isPinned &&
              channelObj.pinnedMessageIds.contains(msg.messageId),
        )
        .toList();
  }

  // Marcar un mensaje como leído (confirmación de lectura)
  bool markAsRead(String channel, String messageId, String readerNick) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;

    final channelObj = channels[normalized]!;
    final messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );

    if (messageIndex == -1) return false;

    final message = channelObj.messages[messageIndex];
    final updatedReadBy = Map<String, DateTime>.from(message.readBy);
    updatedReadBy[readerNick] = DateTime.now();

    final updatedMessage = message.copyWith(readBy: updatedReadBy);
    channelObj.messages[messageIndex] = updatedMessage;
    _notifyMessageListeners(updatedMessage);

    return true;
  }

  // Establecer expiración para un mensaje temporal
  bool setMessageExpiration(
    String channel,
    String messageId,
    Duration expirationDuration,
  ) {
    final normalized = _normalizeChannelName(channel);
    if (!channels.containsKey(normalized)) return false;

    final channelObj = channels[normalized]!;
    final messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );

    if (messageIndex == -1) return false;

    final message = channelObj.messages[messageIndex];
    final expiresAt = DateTime.now().add(expirationDuration);

    final updatedMessage = message.copyWith(expiresAt: expiresAt);
    channelObj.messages[messageIndex] = updatedMessage;
    _notifyMessageListeners(updatedMessage);

    // Programar eliminación automática
    Timer(expirationDuration, () {
      _expireMessage(normalized, messageId);
    });

    return true;
  }

  // Eliminar un mensaje expirado
  void _expireMessage(String channel, String messageId) {
    if (!channels.containsKey(channel)) return;

    final channelObj = channels[channel]!;
    final messageIndex = channelObj.messages.indexWhere(
      (msg) => msg.messageId == messageId,
    );

    if (messageIndex == -1) return;

    final message = channelObj.messages[messageIndex];

    // Verificar que realmente haya expirado
    if (message.expiresAt != null &&
        DateTime.now().isBefore(message.expiresAt!)) {
      return; // Aún no ha expirado
    }

    // Remover el mensaje
    channelObj.messages.removeAt(messageIndex);

    // Si estaba fijado, removerlo de la lista
    channelObj.pinnedMessageIds.remove(messageId);

    // Notificar que el mensaje fue eliminado (crear un mensaje de sistema)
    final systemMessage = IRCMessage(
      nick: 'System',
      channel: channel,
      message: 'Mensaje temporal eliminado',
      timestamp: DateTime.now(),
      isSystem: true,
    );
    _notifyMessageListeners(systemMessage);
    _notifyUserListListeners(channel);
  }

  /// Agregar un mensaje de sistema personalizado (usado para ZNC, etc.)
  void addSystemMessage(String channel, String message) {
    final systemMessage = IRCMessage(
      nick: 'System',
      channel: channel,
      message: message,
      timestamp: DateTime.now(),
      isSystem: true,
    );
    _notifyMessageListeners(systemMessage);
  }

  // Verificar y eliminar mensajes expirados periódicamente
  void _checkExpiredMessages() {
    for (var channelEntry in channels.entries) {
      final channel = channelEntry.value;
      final now = DateTime.now();

      final expiredMessages = channel.messages
          .where((msg) => msg.expiresAt != null && now.isAfter(msg.expiresAt!))
          .toList();

      for (var expiredMsg in expiredMessages) {
        _expireMessage(channelEntry.key, expiredMsg.messageId ?? '');
      }
    }
  }
}
