import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:io' if (dart.library.html) '../utils/io_stub.dart' as io;
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../models/channel_info.dart';
import '../models/server_profile.dart';
import 'chat_screen.dart';
import 'rules_screen.dart';
import '../utils/platform_utils.dart';
import '../services/geoip_service.dart';
import '../config/debug_config.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _hostController = TextEditingController(text: 'ceres.globalchat.org');
  // En web, usar puerto IRC SSL (el gateway maneja la conexión WebSocket)
  final _portController = TextEditingController(
    text: '6697',
  );
  late final TextEditingController _nickController;
  final _channelController = TextEditingController(); // Vacío por defecto
  final _passwordController = TextEditingController(); // Contraseña para identificación
  final _channelFocusNode = FocusNode();
  Function(String)? _nickChangeListener; // Listener para cambios de nick
  bool _isLoading = false;
  String? _errorMessage;
  List<ChannelInfo> _channels = [];
  bool _loadingChannels = false;
  ServerProfile? _selectedServer;
  bool _identifyWithNick = false; // Checkbox para identificar con nick registrado
  bool _obscurePassword = true; // Controlar visibilidad de la contraseña
  String _appVersion = 'v3.0.4'; // Versión por defecto
  bool _isAutoJoining = false; // Flag para indicar que está en proceso de autojoin
  bool _confirmOver14 = false; // Confirmación de ser mayor de 14 años
  /// Controla si se usa geolocalización (ciudad/país y selección de servidor por GeoIP).
  /// Por defecto está DESACTIVADA; solo se activa por parámetro de URL o por el switch del formulario.
  bool _geolocationEnabled = false;
  /// Si true, se considera validada la edad (mayor de 18) por parámetro URL; no hace falta marcar el checkbox.
  bool _urlAge18Validated = false;
  /// Si true, las reglas se aceptaron por parámetro URL.
  bool _urlRulesAccepted = false;
  /// Canal leído del parámetro URL (channel=). Se usa cuando geolocation=false para autojoin y como fallback en _connect().
  String? _urlChannel;
  /// Si el nick vino por URL (para no sobrescribir con el guardado).
  bool _urlNickProvided = false;
  /// Aceptación de reglas del canal/red (checkbox).
  bool _acceptRules = false;
  /// Reconectar automáticamente al abrir la app (opt-in; por defecto false).
  bool _autoReconnectEnabled = false;
  /// Cuenta atrás para auto-conexión (segundos restantes); null = no en cuenta atrás.
  int? _autoConnectCountdown;
  /// Si el usuario canceló la auto-conexión en esta sesión.
  bool _autoConnectCancelled = false;
  /// Timer de la cuenta atrás de auto-conexión.
  Timer? _autoConnectTimer;
  /// Estado del servidor: null = no comprobado, 'checking', 'available', 'unavailable'.
  String? _serverStatus;
  /// Si la sección "Opciones avanzadas" está expandida.
  bool _advancedExpanded = false;
  /// Entrar como invitado desde parámetro URL (guest=1 / invitado=1): mismo comportamiento que el botón.
  bool _guestFromUrl = false;

  static const _prefLastNick = 'login_last_nick';
  static const _prefLastChannel = 'login_last_channel';
  static const _prefRememberIdentify = 'login_remember_identify';
  static const _prefAutoReconnect = 'login_auto_reconnect';
  /// Si el usuario ha activado "reconectar al abrir". Por defecto false: no reconectar hasta que lo active.
  static const _prefAutoReconnectEnabled = 'login_auto_reconnect_enabled';
  static const _prefIdentifyNick = 'login_identify_nick';
  static const _prefIdentifyPassword = 'login_identify_password';

  // Lista de canales prohibidos que no se mostrarán en el combo
  static const List<String> _prohibitedChannels = ['#opers', '#services'];

  /// Comprueba si el nick contiene caracteres no permitidos (ñ, acentos, emojis, etc.).
  /// Solo se permiten [A-Za-z0-9_\-\[\]\\`^{}|].
  bool _nickHasInvalidCharacters(String raw) {
    return RegExp(r'[^A-Za-z0-9_\-\[\]\\`^{}|]').hasMatch(raw.trim());
  }

  /// Limpia el nick para que sea válido en IRC (solo trim y guiones bajos finales).
  /// Usado para URL y para el valor final al conectar cuando la validación ya pasó.
  String _sanitizeNick(String raw) {
    var nick = raw.trim();
    while (nick.endsWith('_')) {
      nick = nick.substring(0, nick.length - 1).trim();
    }
    nick = nick.replaceAll(RegExp(r'[^A-Za-z0-9_\-\[\]\\`^{}|]'), '');
    return nick;
  }

  @override
  void initState() {
    super.initState();
    
    // Logs de consola desactivados para rendimiento
    // debugPrint('🔍 [INIT] LoginScreen initState iniciado');
    // debugLog('🔍 [INIT] LoginScreen initState iniciado - PRINT');
    // if (PlatformUtils.isWeb) {
    //   try {
    //     html.window.console.log('🔍 [INIT] LoginScreen initState iniciado - CONSOLE');
    //   } catch (e) {}
    // }
    
    // Cargar versión de la app
    _loadAppVersion();
    
    // Leer parámetros de la URL PRIMERO (si estamos en web)
    // Esto debe hacerse antes de leer el provider para que los parámetros de URL tengan prioridad
    String? urlNick;
    String? urlChannel;
    bool autoJoin = false;
    // Controlar si se hace autojoin al canal oficial #globalchat (solo web)
    // Por defecto TRUE para mantener el comportamiento actual
    bool? joinChannelOficialFromUrl;
    
    if (PlatformUtils.isWeb) {
      debugLog('🔍 [INIT] PlatformUtils.isWeb = true, leyendo parámetros de URL');
      try {
        final uri = Uri.base;
        debugLog('🔍 [URL] Uri.base: $uri');
        debugLog('🔍 [URL] Uri.base.queryParameters: ${uri.queryParameters}');

          final nickParam = uri.queryParameters['nick'];
          final channelParam = uri.queryParameters['channel'];
          final autoJoinParam = uri.queryParameters['autojoin'];
          final joinOficialParam = uri.queryParameters['joinchanneloficial'];
          final geolocationParam = uri.queryParameters['geolocation'];
          final age18Param = uri.queryParameters['age18'] ?? uri.queryParameters['age'];
          final rulesParam = uri.queryParameters['rules'] ??
              uri.queryParameters['reglas'] ??
              uri.queryParameters['normas'];
          final guestParam = uri.queryParameters['guest'] ?? uri.queryParameters['invitado'];
          
          if (guestParam != null) {
            final v = guestParam.toLowerCase().trim();
            if (v == 'true' || v == '1' || v == 'yes') {
              _guestFromUrl = true;
              urlChannel = '#globalchat';
              _confirmOver14 = true;
              _acceptRules = true;
              _urlAge18Validated = true;
              _urlRulesAccepted = true;
              debugLog('🔍 [URL] ✅ guest/invitado=1 (Uri.base): entrar como invitado por parámetro');
            }
          }
          
          if (!_guestFromUrl && nickParam != null && nickParam.trim().isNotEmpty) {
            final sanitized = _sanitizeNick(nickParam);
            if (sanitized.isNotEmpty) {
              urlNick = sanitized;
              debugLog('🔍 [URL] ✅ Nick leído de Uri.base: "$nickParam" -> Sanitizado: "$urlNick"');
            } else {
              debugLog('🔍 [URL] ⚠️ Nick inválido tras sanitizar (Uri.base): "$nickParam"');
            }
          }
          
          if (!_guestFromUrl && channelParam != null) {
            final trimmed = channelParam.trim();
            if (trimmed.isNotEmpty && trimmed != '=') {
              urlChannel = trimmed;
              debugLog('🔍 [URL] ✅ Canal leído de Uri.base: "$urlChannel"');
            }
          }
          
          if (autoJoinParam != null) {
            final autoJoinValue = autoJoinParam.toLowerCase().trim();
            autoJoin = autoJoinValue == 'true' || 
                       autoJoinValue == '1' || 
                       autoJoinValue == 'yes';
            debugLog('🔍 [URL] ✅ autoJoin leído de Uri.base: "$autoJoinParam" -> autoJoin=$autoJoin');
          }

          if (joinOficialParam != null) {
            final value = joinOficialParam.toLowerCase().trim();
            if (value == 'false' || value == '0' || value == 'no') {
              joinChannelOficialFromUrl = false;
            } else if (value == 'true' || value == '1' || value == 'yes') {
              joinChannelOficialFromUrl = true;
            }
            debugLog('🔍 [URL] ✅ joinchanneloficial leído de Uri.base: "$joinOficialParam" -> $joinChannelOficialFromUrl');
          }
          if (geolocationParam != null) {
            final v = geolocationParam.toLowerCase().trim();
            _geolocationEnabled = v != 'false' && v != '0' && v != 'no';
          }
          if (age18Param != null) {
            final v = age18Param.toLowerCase().trim();
            _urlAge18Validated = v == 'true' || v == '1' || v == 'yes';
            if (_urlAge18Validated) {
              _confirmOver14 = true;
              _acceptRules = true;
              _urlRulesAccepted = true;
            }
          }
          if (rulesParam != null) {
            final v = rulesParam.toLowerCase().trim();
            if (v == 'true' || v == '1' || v == 'yes') {
              _acceptRules = true;
              _urlRulesAccepted = true;
            }
          }

        // Guardar canal de URL en instancia para usarlo en _connect() y en el callback (geolocation=false)
        _urlChannel = urlChannel;
        // Debug: verificar que se leyeron los parámetros
        debugLog('🔍 [URL] Parámetros finales - nick: $urlNick, channel: $urlChannel, autojoin: $autoJoin, joinchanneloficial: $joinChannelOficialFromUrl, geolocation: $_geolocationEnabled, age18: $_urlAge18Validated, guest: $_guestFromUrl');
        // Forzar rebuild si la URL activa checks para que se reflejen visualmente.
        if (_urlAge18Validated || _urlRulesAccepted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                if (_urlAge18Validated) _confirmOver14 = true;
                if (_urlAge18Validated || _urlRulesAccepted) _acceptRules = true;
              });
            }
          });
        }
      } catch (e) {
        debugLog('🔍 [URL] Error leyendo URL: $e');
      }
    }

    // Configurar si se permite mostrar el modal de identificación NickServ:
    // Solo se activará cuando la sesión venga por URL con autojoin=true en web.
    final allowNickModal = PlatformUtils.isWeb && autoJoin;
    ref.read(nickIdentifyModalAllowedProvider.notifier).state = allowNickModal;
    debugLog('🔐 [LOGIN] nickIdentifyModalAllowed = $allowNickModal (autoJoin=$autoJoin, isWeb=${PlatformUtils.isWeb})');
    
    // Generar un nickname aleatorio: GlobalChat-XXXXX (número aleatorio de 4-5 dígitos)
    // O usar el de la URL si está presente
    final random = Random();
    final randomNumber = random.nextInt(90000) + 10000; // Número entre 10000 y 99999
    // Asegurarse de que el nick de la URL esté limpio (sin guiones al final)
    final cleanUrlNick = urlNick?.trim();
    final defaultNick = cleanUrlNick ?? 'GlobalChat-$randomNumber';
    if (cleanUrlNick != null && cleanUrlNick.isNotEmpty) _urlNickProvided = true;
    _nickController = TextEditingController(
      text: _guestFromUrl ? 'Invitado${random.nextInt(90000) + 10000}' : defaultNick,
    );
    if (_guestFromUrl) _urlNickProvided = true;
    debugLog('🔍 [LOGIN] NickController inicializado con: "${_nickController.text}"');

    // Si es la primera vez y no hay servidor seleccionado aún,
    // preseleccionar un servidor SSL aleatorio en el desplegable.
    if (_selectedServer == null) {
      final sslServers = ServerProfile.defaultGlobalChatProfiles
          .where((profile) => profile.port == 6697 && profile.useSSL)
          .toList();
      if (sslServers.isNotEmpty) {
        final randomIndex = random.nextInt(sslServers.length);
        _selectedServer = sslServers[randomIndex];
        _updateServerFields(_selectedServer!);
        debugLog('🔍 [LOGIN] Servidor inicial aleatorio seleccionado: ${_selectedServer!.host}:${_selectedServer!.port}');
      }
    }
    
    // Aplicar configuración de auto-join al canal oficial #globalchat si viene en la URL
    // Solo tiene efecto en web
    if (PlatformUtils.isWeb && joinChannelOficialFromUrl != null) {
      final ircService = ref.read(ircServiceProvider);
      ircService.setAutoJoinOfficialGlobalChat(joinChannelOficialFromUrl);
      debugLog('🌐 [LOGIN] joinchanneloficial aplicado al IRCService: $joinChannelOficialFromUrl');
    }

    // Pre-llenar el canal si viene en la URL (usa _urlChannel ya asignado arriba)
    if (_urlChannel != null && _urlChannel!.trim().isNotEmpty) {
      String channel = _urlChannel!.trim();
      // Asegurar que empiece con #
      if (!channel.startsWith('#')) {
        channel = '#$channel';
      }
      _channelController.text = channel;
      debugLog('🔍 [URL] ✅ Canal aplicado al controlador: $channel');
      debugLog('🔍 [URL] Verificación - _channelController.text = "${_channelController.text}"');
    } else {
      debugLog('🔍 [URL] ⚠️ No se aplicó canal - _urlChannel: $_urlChannel');
    }
    
    // Leer servidor seleccionado del provider (si se cambió desde el AppBar)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Esperar un momento para asegurar que el provider se haya inicializado
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Cargar preferencias guardadas (último nick, canal, recordar identificar)
      await _loadLoginPrefs();
      if (mounted && (_urlAge18Validated || _urlRulesAccepted)) {
        setState(() {
          if (_urlAge18Validated) _confirmOver14 = true;
          if (_urlAge18Validated || _urlRulesAccepted) _acceptRules = true;
        });
      }
      // Aplicar servidor guardado (para reconexión automática)
      if (mounted) {
        final profile = ref.read(currentServerProfileProvider);
        if (profile != null) {
          setState(() {
            _selectedServer = profile;
            _updateServerFields(profile);
          });
        }
        // No auto-conectar al abrir: siempre mostrar el formulario para que el usuario
        // pueda configurar nick/canal y conectar cuando pulse "Conectar".
      }
      if (mounted) _checkServerStatus();
      
      // En web: obtener ciudad/región/país por GeoIP y añadir join a canales de país y ciudad/región (si geolocation está activado)
      if (PlatformUtils.isWeb && _geolocationEnabled) {
        try {
          final loc = await GeoIPService.getCityRegion();
          if (loc != null && mounted) {
            final city = loc['city'];
            final region = loc['region'];
            final country = loc['country'];
            final channelCity = GeoIPService.cityRegionToChannelName(city, region);
            final channelCountry = country != null && country.isNotEmpty
                ? GeoIPService.countryToChannelName(country)
                : null;
            final hasUrlChannel = _urlChannel != null && _urlChannel!.trim().isNotEmpty;
            final currentChannelStored = ref.read(currentChannelProvider);
            final autoJoinChannels = ref.read(autoJoinChannelsProvider);
            final geoChannels = <String>[
              if (channelCountry != null && channelCountry != channelCity) channelCountry,
              channelCity,
            ];
            if (!hasUrlChannel && (currentChannelStored == null || currentChannelStored.isEmpty) && autoJoinChannels.isEmpty) {
              _channelController.text = channelCity;
              ref.read(currentChannelProvider.notifier).state = channelCity;
              ref.read(autoJoinChannelsProvider.notifier).state = geoChannels;
              debugLog('🌍 [GEOIP] Canales por país/ciudad (sin canal previo): $geoChannels');
            } else {
              final urlCh = _urlChannel?.trim() ?? '';
              final mainChannel = hasUrlChannel && urlCh.isNotEmpty
                  ? (urlCh.startsWith('#') ? urlCh : '#$urlCh')
                  : (currentChannelStored ?? _channelController.text.trim());
              final mainNorm = mainChannel.isNotEmpty ? (mainChannel.startsWith('#') ? mainChannel : '#$mainChannel') : null;
              final toJoin = <String>[];
              if (mainNorm != null) toJoin.add(mainNorm);
              for (final ch in geoChannels) {
                if (!toJoin.contains(ch)) toJoin.add(ch);
              }
              ref.read(autoJoinChannelsProvider.notifier).state = toJoin;
              if (mainNorm != null) {
                ref.read(currentChannelProvider.notifier).state = mainNorm;
                _channelController.text = mainNorm;
              }
              debugLog('🌍 [GEOIP] Añadido join a canales país y ciudad/región: $geoChannels (canales: $toJoin)');
            }
          }
        } catch (e) {
          debugLog('🌍 [GEOIP] Error obteniendo ciudad/región/país: $e');
        }
      }
      
      final selectedServerProfile = ref.read(currentServerProfileProvider);
      final currentChannel = ref.read(currentChannelProvider);
      final currentNick = ref.read(currentNicknameProvider);
      final autoJoinChannels = ref.read(autoJoinChannelsProvider);
      
      debugLog('🔍 [LOGIN] ========== INICIO LOGIN ==========');
      debugLog('🔍 [LOGIN] Estado inicial - servidor: ${selectedServerProfile?.name ?? "null"}');
      debugLog('🔍 [LOGIN] Servidor host: ${selectedServerProfile?.host ?? "null"}, port: ${selectedServerProfile?.port ?? "null"}');
      debugLog('🔍 [LOGIN] Nick: $currentNick');
      debugLog('🔍 [LOGIN] Canal: $currentChannel');
      debugLog('🔍 [LOGIN] Canales autojoin: $autoJoinChannels');
      debugLog('🔍 [LOGIN] Canal desde URL: $_urlChannel');
      debugLog('🔍 [LOGIN] ===================================');
      
      // Verificar si hay datos guardados para autojoin (viene de cambio de servidor)
      final hasAutoJoinData = currentNick != null && currentNick.isNotEmpty && 
                             (currentChannel != null && currentChannel.isNotEmpty || autoJoinChannels.isNotEmpty);
      
      if (selectedServerProfile != null) {
        debugLog('🔍 [LOGIN] ✅ Servidor seleccionado desde provider: ${selectedServerProfile.name}');
        debugLog('🔍 [LOGIN] Servidor host: ${selectedServerProfile.host}, port: ${selectedServerProfile.port}');
        _selectedServer = selectedServerProfile;
        _updateServerFields(selectedServerProfile);
        
        // Verificar que los campos se actualizaron correctamente
        debugLog('🔍 [LOGIN] Campos actualizados - host: ${_hostController.text}, port: ${_portController.text}');
        
        // Obtener el canal actual si existe (solo si no hay canal de URL)
        if (_urlChannel == null || _urlChannel!.isEmpty) {
          if (currentChannel != null && currentChannel.isNotEmpty) {
            _channelController.text = currentChannel;
            debugLog('🔍 [LOGIN] Canal actual desde provider: $currentChannel');
          } else if (autoJoinChannels.isNotEmpty) {
            // Si no hay canal actual pero hay canales para autojoin, usar el primero
            _channelController.text = autoJoinChannels.first;
            debugLog('🔍 [LOGIN] Usando primer canal de autojoin: ${autoJoinChannels.first}');
          }
        } else {
          debugLog('🔍 [LOGIN] Canal de URL tiene prioridad, no se sobrescribe con provider');
        }
        
        // Obtener el nick del provider si está disponible (solo si no hay nick de URL)
        if ((urlNick == null || urlNick.isEmpty) && currentNick != null && currentNick.isNotEmpty) {
          _nickController.text = currentNick;
          debugLog('🔍 [LOGIN] Nick actual desde provider: $currentNick');
        } else if (urlNick != null && urlNick.isNotEmpty) {
          debugLog('🔍 [LOGIN] Nick de URL tiene prioridad, no se sobrescribe con provider');
        }
        
        // Hacer autojoin automáticamente cuando se cambia de servidor
        // PERO solo si NO viene autojoin desde la URL (para evitar doble conexión)
        if (hasAutoJoinData && !(autoJoin && PlatformUtils.isWeb)) {
          debugLog('🔍 [AUTOJOIN] ✅ Condiciones cumplidas para autojoin: servidor=${selectedServerProfile.name}, nick=$currentNick, canales=$autoJoinChannels');
          
          // Esperar un momento para que los campos se actualicen
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            
            final host = _hostController.text.trim();
            final portText = _portController.text.trim();
            final port = int.tryParse(portText) ?? 6697;
            final nick = _nickController.text.trim();
            final channel = _channelController.text.trim();
            
            debugLog('🔍 [AUTOJOIN] Verificando campos: host=$host, port=$port, nick=$nick, channel=$channel');
            
            if (host.isNotEmpty && nick.isNotEmpty && channel.isNotEmpty) {
              debugLog('🔍 [AUTOJOIN] ✅ Todos los campos están completos, iniciando conexión...');
              debugLog('🔍 [AUTOJOIN] Auto-uniéndose después de cambiar servidor: host=$host, port=$port, nick=$nick, channel=$channel');
              
              setState(() {
                _isAutoJoining = true;
                _isLoading = true;
              });
              
              try {
                await _connect();
                debugLog('🔍 [AUTOJOIN] ✅ Conexión exitosa después de cambiar servidor');
              } catch (e) {
                debugLog('🔍 [AUTOJOIN] ❌ Error en conexión: $e');
                if (mounted) {
                  setState(() {
                    _errorMessage = 'Error en auto-join: $e';
                    _isLoading = false;
                    _isAutoJoining = false;
                  });
                }
              }
            } else {
              debugLog('🔍 [AUTOJOIN] ⚠️ Campos incompletos - host: ${host.isNotEmpty}, nick: ${nick.isNotEmpty}, channel: ${channel.isNotEmpty}');
            }
          });
        } else {
          if (autoJoin && PlatformUtils.isWeb) {
            debugLog('🔍 [LOGIN] Autojoin desde URL tiene prioridad, no se ejecuta autojoin desde provider');
          } else {
            debugLog('🔍 [LOGIN] No se cumplen condiciones para autojoin - nick: ${currentNick != null && currentNick.isNotEmpty}, canal: ${currentChannel != null && currentChannel.isNotEmpty}, canales autojoin: ${autoJoinChannels.isNotEmpty}');
          }
        }
      } else {
        debugLog('🔍 [LOGIN] No hay servidor seleccionado en el provider, usando selección por GeoIP');
        
        // Si autojoin está activado desde URL y no hay servidor seleccionado, hacer autojoin
        if (autoJoin && PlatformUtils.isWeb && (urlNick != null || _urlChannel != null)) {
          debugLog('🔍 [AUTOJOIN_URL] ✅ Autojoin activado desde URL - nick: $urlNick, channel: $_urlChannel');
          
          // Asegurar que el canal esté en el controlador (prioridad: URL, luego formulario)
          var channelToUse = _urlChannel?.trim();
          if (channelToUse == null || channelToUse.isEmpty) {
            channelToUse = _channelController.text.trim();
          }
          
          if (channelToUse.isNotEmpty) {
            // Normalizar el canal
            String finalChannel = channelToUse;
            if (!finalChannel.startsWith('#')) {
              finalChannel = '#$finalChannel';
            }
            _channelController.text = finalChannel;
            debugLog('🔍 [AUTOJOIN_URL] Canal normalizado: $finalChannel');
            
            // Filtrar servidores con puerto 6697 (SSL)
            final sslServers = ServerProfile.defaultGlobalChatProfiles
                .where((profile) => profile.port == 6697 && profile.useSSL)
                .toList();
            
            if (sslServers.isNotEmpty) {
              // Asegurar que el puerto sea 6697
              _portController.text = '6697';
              
              // Detectar ubicación geográfica usando GeoIP y seleccionar servidor (o aleatorio si geolocation=false)
              if (_geolocationEnabled) {
                await _selectServerByGeoIPFromList(sslServers);
              } else {
                final random = Random();
                _selectedServer = sslServers[random.nextInt(sslServers.length)];
                _updateServerFields(_selectedServer!);
              }
              
              // Esperar un momento para asegurar que el servidor se haya actualizado
              await Future.delayed(const Duration(milliseconds: 500));
              
              // Conectar automáticamente
              if (mounted) {
                // Verificar que tenemos todos los datos necesarios
                final host = _hostController.text.trim();
                final portText = _portController.text.trim();
                final port = int.tryParse(portText) ?? 6697;
                final nick = _nickController.text.trim();
                final channel = _channelController.text.trim();
                
                // Verificar que todos los campos estén completos
                if (host.isNotEmpty && nick.isNotEmpty && channel.isNotEmpty) {
                  debugLog('🔍 [AUTOJOIN_URL] Intentando conectar: host=$host, port=$port, nick=$nick, channel=$channel');
                  
                  // Mostrar estado de carga para autojoin
                  setState(() {
                    _isAutoJoining = true;
                    _isLoading = true;
                  });
                  
                  // Conectar automáticamente
                  try {
                    await _connect();
                    debugLog('🔍 [AUTOJOIN_URL] ✅ Conexión exitosa');
                  } catch (e) {
                    debugLog('🔍 [AUTOJOIN_URL] ❌ Error en conexión: $e');
                    // Si hay error, mostrar mensaje pero no bloquear
                    if (mounted) {
                      setState(() {
                        _errorMessage = 'Error en auto-join: $e';
                        _isLoading = false;
                        _isAutoJoining = false;
                      });
                    }
                  }
                } else {
                  debugLog('🔍 [AUTOJOIN_URL] ⚠️ Campos incompletos - host: ${host.isNotEmpty}, nick: ${nick.isNotEmpty}, channel: ${channel.isNotEmpty}');
                }
              }
            } else {
              if (_geolocationEnabled) {
                await _selectServerByGeoIP();
              } else {
                final sslServers = ServerProfile.defaultGlobalChatProfiles
                    .where((p) => p.port == 6697 && p.useSSL)
                    .toList();
                if (sslServers.isNotEmpty) {
                  final random = Random();
                  _selectedServer = sslServers[random.nextInt(sslServers.length)];
                  _updateServerFields(_selectedServer!);
                } else {
                  await _selectServerByGeoIP();
                }
              }
            }
            } else {
              if (_geolocationEnabled) {
                await _selectServerByGeoIP();
              } else {
              final sslServers = ServerProfile.defaultGlobalChatProfiles
                  .where((p) => p.port == 6697 && p.useSSL)
                  .toList();
              if (sslServers.isNotEmpty) {
                final random = Random();
                _selectedServer = sslServers[random.nextInt(sslServers.length)];
                _updateServerFields(_selectedServer!);
              } else {
                await _selectServerByGeoIP();
              }
            }
          }
        }
      }
      
      // Entrar como invitado por parámetro URL (guest=1 / invitado=1): conectar automáticamente
      if (_guestFromUrl && PlatformUtils.isWeb && mounted) {
        Future.delayed(const Duration(milliseconds: 500), () async {
          if (!mounted) return;
          setState(() { _isLoading = true; });
          try {
            await _connect();
            debugLog('🔍 [URL] ✅ Conexión como invitado por parámetro OK');
          } catch (e) {
            debugLog('🔍 [URL] ❌ Error conexión invitado por parámetro: $e');
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = 'Error al conectar: $e';
              });
            }
          }
        });
      }
    });
    
    _loadChannels();
  }

  /// Seleccionar servidor basado en GeoIP desde una lista específica
  /// América → caliope.globalchat.org
  /// Resto del mundo → otros servidores (ceres, creta, apolo)
  Future<void> _selectServerByGeoIPFromList(List<ServerProfile> sslServers) async {
    late ServerProfile selectedServer;
    
    try {
      final isAmericas = await GeoIPService.isInAmericas();
      
      if (isAmericas == true) {
        // Si está en América, usar caliope
        selectedServer = sslServers.firstWhere(
          (profile) => profile.host == 'caliope.globalchat.org',
          orElse: () => sslServers.first,
        );
        if (PlatformUtils.isWeb) {
          debugLog('🌎 [GEOIP] Usuario en América, usando Caliope');
        }
      } else if (isAmericas == false) {
        // Si está fuera de América, usar otros servidores (excluyendo caliope)
        var nonAmericasServers = sslServers
            .where((profile) => profile.host != 'caliope.globalchat.org')
            .toList();
        // En web, evitar seleccionar Apolo por defecto (solo si el usuario lo elige explícitamente)
        if (PlatformUtils.isWeb) {
          final filtered = nonAmericasServers
              .where((profile) => profile.host != 'apolo.globalchat.org')
              .toList();
          if (filtered.isNotEmpty) {
            nonAmericasServers = filtered;
          }
        }
        
        if (nonAmericasServers.isNotEmpty) {
          // Seleccionar aleatoriamente entre los servidores no americanos
          final random = Random();
          final selectedIndex = random.nextInt(nonAmericasServers.length);
          selectedServer = nonAmericasServers[selectedIndex];
          if (PlatformUtils.isWeb) {
            debugLog('🌎 [GEOIP] Usuario fuera de América, usando ${selectedServer.host}');
          }
        } else {
          // Fallback si no hay otros servidores
          selectedServer = sslServers.first;
          if (PlatformUtils.isWeb) {
            debugLog('🌎 [GEOIP] No hay servidores disponibles, usando por defecto');
          }
        }
      } else {
        // Si no se puede determinar la ubicación, usar selección aleatoria normal
        final random = Random();
        final selectedIndex = random.nextInt(sslServers.length);
        selectedServer = sslServers[selectedIndex];
        if (PlatformUtils.isWeb) {
          debugLog('🌎 [GEOIP] No se pudo determinar ubicación, usando selección aleatoria');
        }
      }
    } catch (e) {
      // Si hay error en GeoIP, usar selección aleatoria normal
      if (PlatformUtils.isWeb) {
        debugLog('🌎 [GEOIP] Error al detectar ubicación: $e, usando selección aleatoria');
      }
      final random = Random();
      final selectedIndex = random.nextInt(sslServers.length);
      selectedServer = sslServers[selectedIndex];
    }
    
    if (mounted) {
      setState(() {
        _selectedServer = selectedServer;
        _updateServerFields(_selectedServer!);
      });
    }
  }

  /// Seleccionar servidor basado en GeoIP
  /// América → caliope.globalchat.org
  /// Resto del mundo → otros servidores (ceres, creta, apolo)
  Future<void> _selectServerByGeoIP() async {
    final sslServers = ServerProfile.defaultGlobalChatProfiles
        .where((profile) => profile.port == 6697 && profile.useSSL)
        .toList();
    
    if (sslServers.isEmpty) {
      // Fallback si no hay servidores SSL
      _selectedServer = ServerProfile.defaultGlobalChatProfiles.firstWhere(
        (profile) => profile.isDefault,
        orElse: () => ServerProfile.defaultGlobalChatProfiles.first,
      );
      _updateServerFields(_selectedServer!);
      return;
    }
    
    ServerProfile? selectedServer;
    
    try {
      final isAmericas = await GeoIPService.isInAmericas();
      
      if (isAmericas == true) {
        // Si está en América, usar caliope
        selectedServer = sslServers.firstWhere(
          (profile) => profile.host == 'caliope.globalchat.org',
          orElse: () => sslServers.first,
        );
        if (PlatformUtils.isWeb) {
          debugLog('🌎 [GEOIP] Usuario en América, usando Caliope');
        }
      } else if (isAmericas == false) {
        // Si está fuera de América, usar otros servidores (excluyendo caliope)
        var nonAmericasServers = sslServers
            .where((profile) => profile.host != 'caliope.globalchat.org')
            .toList();
        // En web, evitar seleccionar Apolo por defecto (solo si el usuario lo elige explícitamente)
        if (PlatformUtils.isWeb) {
          final filtered = nonAmericasServers
              .where((profile) => profile.host != 'apolo.globalchat.org')
              .toList();
          if (filtered.isNotEmpty) {
            nonAmericasServers = filtered;
          }
        }
        
        if (nonAmericasServers.isNotEmpty) {
          // Seleccionar aleatoriamente entre los servidores no americanos
          final random = Random();
          final selectedIndex = random.nextInt(nonAmericasServers.length);
          selectedServer = nonAmericasServers[selectedIndex];
          if (PlatformUtils.isWeb) {
            debugLog('🌎 [GEOIP] Usuario fuera de América, usando ${selectedServer.host}');
          }
        } else {
          // Fallback si no hay otros servidores
          selectedServer = sslServers.first;
          if (PlatformUtils.isWeb) {
            debugLog('🌎 [GEOIP] No hay servidores disponibles, usando por defecto');
          }
        }
      } else {
        // Si no se puede determinar la ubicación, usar selección aleatoria normal
        final random = Random();
        final selectedIndex = random.nextInt(sslServers.length);
        selectedServer = sslServers[selectedIndex];
        if (PlatformUtils.isWeb) {
          debugLog('🌎 [GEOIP] No se pudo determinar ubicación, usando selección aleatoria');
        }
      }
    } catch (e) {
      // Si hay error en GeoIP, usar selección aleatoria normal
      if (PlatformUtils.isWeb) {
        debugLog('🌎 [GEOIP] Error al detectar ubicación: $e, usando selección aleatoria');
      }
      final random = Random();
      final selectedIndex = random.nextInt(sslServers.length);
      selectedServer = sslServers[selectedIndex];
    }
    
    _selectedServer = selectedServer;
    _updateServerFields(selectedServer);
  }

  void _updateServerFields(ServerProfile profile) {
    _hostController.text = profile.host;
    _portController.text = profile.port.toString();
  }

  Future<void> _loadLoginPrefs() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedNick = prefs.getString(_prefLastNick);
      final savedChannel = prefs.getString(_prefLastChannel);
      final savedIdentify = prefs.getBool(_prefRememberIdentify);
      if (!_urlNickProvided && savedNick != null && savedNick.trim().isNotEmpty) {
        _nickController.text = savedNick.trim();
        debugLog('🔍 [LOGIN] Nick restaurado: $savedNick');
      }
      if ((_urlChannel == null || _urlChannel!.trim().isEmpty) && savedChannel != null && savedChannel.trim().isNotEmpty) {
        String ch = savedChannel.trim();
        if (!ch.startsWith('#')) ch = '#$ch';
        _channelController.text = ch;
        debugLog('🔍 [LOGIN] Canal restaurado: $ch');
      }
      if (savedIdentify != null) {
        _identifyWithNick = savedIdentify;
        debugLog('🔍 [LOGIN] Recordar identificar: $savedIdentify');
      }
      // Restaurar contraseña solo si coincide el nick con el que se guardó
      if (_identifyWithNick && savedNick != null && savedNick.trim().isNotEmpty) {
        final savedPasswordNick = prefs.getString(_prefIdentifyNick);
        if (savedPasswordNick != null && savedPasswordNick.trim() == savedNick.trim()) {
          final savedPassword = prefs.getString(_prefIdentifyPassword);
          if (savedPassword != null && savedPassword.isNotEmpty) {
            _passwordController.text = savedPassword;
            debugLog('🔍 [LOGIN] Contraseña de identificación restaurada para nick: $savedNick');
          }
        }
      }
      final savedAutoReconnectEnabled = prefs.getBool(_prefAutoReconnectEnabled);
      if (savedAutoReconnectEnabled != null) {
        _autoReconnectEnabled = savedAutoReconnectEnabled;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugLog('🔍 [LOGIN] Error cargando preferencias: $e');
    }
  }

  Future<void> _saveLoginPrefs(String nick, String channel, bool identifyWithNick, {String? identifyPassword}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefLastNick, nick.trim());
      if (channel.trim().isNotEmpty) {
        await prefs.setString(_prefLastChannel, channel.trim());
      }
      await prefs.setBool(_prefRememberIdentify, identifyWithNick);
      if (identifyWithNick && identifyPassword != null && identifyPassword.isNotEmpty) {
        await prefs.setString(_prefIdentifyNick, nick.trim());
        await prefs.setString(_prefIdentifyPassword, identifyPassword);
        debugLog('🔍 [LOGIN] Contraseña de identificación guardada para nick: $nick');
      } else if (!identifyWithNick) {
        await prefs.remove(_prefIdentifyNick);
        await prefs.remove(_prefIdentifyPassword);
      }
    } catch (e) {
      debugLog('🔍 [LOGIN] Error guardando preferencias: $e');
    }
  }

  void _generateRandomNick() {
    final random = Random();
    final n = random.nextInt(90000) + 10000;
    _nickController.text = 'GlobalChat-$n';
    setState(() {});
  }

  void _enterAsGuest() {
    final random = Random();
    _nickController.text = 'Invitado${random.nextInt(90000) + 10000}';
    _channelController.text = '#globalchat';
    setState(() {});
    _connect();
  }

  Future<void> _checkServerStatus() async {
    final host = _hostController.text.trim();
    final portStr = _portController.text.trim();
    final port = int.tryParse(portStr) ?? 6697;
    if (host.isEmpty) {
      setState(() => _serverStatus = null);
      return;
    }
    setState(() => _serverStatus = 'checking');
    try {
      if (PlatformUtils.isWeb) {
        setState(() => _serverStatus = null);
        return;
      }
      final s = await io.Socket.connect(host, port, timeout: const Duration(seconds: 3));
      s.destroy();
      if (mounted) setState(() => _serverStatus = 'available');
    } catch (_) {
      if (mounted) setState(() => _serverStatus = 'unavailable');
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _loadChannels() async {
    setState(() {
      _loadingChannels = true;
    });

    try {
      final response = await http.get(
        Uri.parse('https://canales.globalchat.org/proxy/channels.php'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['channels'] != null) {
          final List<dynamic> channelsJson = data['channels'];
          setState(() {
            _channels = channelsJson
                .map((json) => ChannelInfo.fromJson(json))
                .where((channel) {
                  // Filtrar canales prohibidos (case-insensitive)
                  final channelNameLower = channel.name.toLowerCase();
                  return !_prohibitedChannels.any(
                    (prohibited) => channelNameLower == prohibited.toLowerCase()
                  );
                })
                .toList()
              ..sort((a, b) => b.users.compareTo(a.users)); // Ordenar por usuarios (mayor a menor)
            _loadingChannels = false;
          });
          // debugLog('🔍 [DEBUG] Canales cargados: ${_channels.length}');
        }
      }
    } catch (e) {
      // debugLog('Error cargando canales: $e');
      setState(() {
        _loadingChannels = false;
      });
    }
  }

  /// Aplicar sugerencias de canales basadas en GeoIP cuando el usuario
  /// activa manualmente la opción de ubicación.
  Future<void> _applyGeoIpChannelsFromToggle() async {
    if (!PlatformUtils.isWeb || !_geolocationEnabled) return;
    try {
      final loc = await GeoIPService.getCityRegion();
      if (loc == null || !mounted || !_geolocationEnabled) return;

      final city = loc['city'];
      final region = loc['region'];
      final country = loc['country'];
      final channelCity = GeoIPService.cityRegionToChannelName(city, region);
      final channelCountry = country != null && country.isNotEmpty
          ? GeoIPService.countryToChannelName(country)
          : null;

      final geoChannels = <String>[
        if (channelCountry != null && channelCountry != channelCity) channelCountry,
        channelCity,
      ];

      // Si el usuario no ha puesto canal aún, usar la ciudad.
      final currentChannelText = _channelController.text.trim();
      String mainChannel = currentChannelText.isEmpty || currentChannelText == '#'
          ? channelCity
          : currentChannelText;

      // Normalizar canal principal
      if (mainChannel.isNotEmpty && !mainChannel.startsWith('#')) {
        mainChannel = '#$mainChannel';
      }

      final toJoin = <String>[];
      if (mainChannel.isNotEmpty) {
        toJoin.add(mainChannel);
      }
      for (final ch in geoChannels) {
        if (!toJoin.contains(ch)) {
          toJoin.add(ch);
        }
      }

      ref.read(autoJoinChannelsProvider.notifier).state = toJoin;
      if (mainChannel.isNotEmpty) {
        ref.read(currentChannelProvider.notifier).state = mainChannel;
        setState(() {
          _channelController.text = mainChannel;
        });
      }

      debugLog('🌍 [GEOIP] (toggle) Canales sugeridos: $geoChannels (canales: $toJoin)');
    } catch (e) {
      debugLog('🌍 [GEOIP] Error al obtener GeoIP desde toggle: $e');
    }
  }

  /// Limpiar canal y autojoin cuando se desactiva la geolocalización
  /// desde el switch del formulario.
  void _clearGeoIpChannelsFromToggle() {
    if (!PlatformUtils.isWeb) return;
    // Limpiar lista de canales para autojoin y canal actual;
    // el usuario elegirá manualmente el canal.
    try {
      ref.read(autoJoinChannelsProvider.notifier).state = [];
      ref.read(currentChannelProvider.notifier).state = '';
    } catch (_) {}
    setState(() {
      _channelController.text = '';
    });
    debugLog('🌍 [GEOIP] (toggle) Desactivado: canal y autojoin limpiados para selección manual');
  }

  // Cargar información de versión de la app
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
      debugLog('🔍 [LOGIN] App version: $_appVersion');
    } catch (e) {
      debugLog('❌ [LOGIN] Error loading app version: $e');
      // Mantener versión por defecto
    }
  }

  @override
  void dispose() {
    _autoConnectTimer?.cancel();
    _autoConnectTimer = null;
    // Eliminar listener de cambio de nick si existe
    if (_nickChangeListener != null) {
      final ircService = ref.read(ircServiceProvider);
      ircService.removeNickChangeListener(_nickChangeListener!);
    }
    _hostController.dispose();
    _portController.dispose();
    _nickController.dispose();
    _channelController.dispose();
    _passwordController.dispose();
    _channelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_confirmOver14) {
      setState(() {
        _errorMessage = 'Debes confirmar que eres mayor de 14 años para continuar.';
        _isLoading = false;
        _isAutoJoining = false;
      });
      return;
    }
    if (!_acceptRules) {
      setState(() {
        _errorMessage = 'Debes aceptar las reglas del canal/red para continuar.';
        _isLoading = false;
        _isAutoJoining = false;
      });
      return;
    }

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 6697;
    if (_nickHasInvalidCharacters(_nickController.text)) {
      setState(() {
        _errorMessage = 'El nick no puede contener ñ, acentos, emojis ni otros caracteres especiales. '
            'Solo se permiten letras (a-z, A-Z), números y los caracteres _ - [ ] \\ ` ^ { } |';
        _isLoading = false;
        _isAutoJoining = false;
      });
      return;
    }
    var nick = _sanitizeNick(_nickController.text);
    var channel = _channelController.text.trim();
    // Si el canal está vacío pero tenemos canal en la URL (p. ej. geolocation=false), usarlo
    if (channel.isEmpty && _urlChannel != null && _urlChannel!.trim().isNotEmpty) {
      String ch = _urlChannel!.trim();
      if (!ch.startsWith('#')) ch = '#$ch';
      channel = ch.toLowerCase();
      _channelController.text = channel;
      debugLog('🔍 [LOGIN] Canal tomado de URL (_urlChannel): $channel');
    }
    
    debugLog('🔍 [LOGIN] Nick procesado: "${_nickController.text}" -> "$nick"');

    if (host.isEmpty || nick.isEmpty || channel.isEmpty) {
      setState(() => _errorMessage = 'Por favor completa todos los campos');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // globalLog('========================================');
      // globalLog('🔵 [LOGIN] Starting connection');
      // globalLog('========================================');
      
      final ircService = ref.read(ircServiceProvider);
      
      // globalLog('🔵 [LOGIN] Got IRCService instance');
      // globalLog('🔵 [LOGIN] Calling connect() with $host:$port as $nick');
      
      // FORZAR SSL en todas las conexiones
      final useSSL = true;
      
      // En web, el gateway maneja la conexión, así que siempre pasamos el puerto IRC real
      // El gateway se conecta internamente al servidor IRC usando este puerto
      // Añadir listener para actualizar el provider cuando el nick cambie (por ejemplo, si se añade guion)
      _nickChangeListener = (newNick) {
        if (mounted) {
          ref.read(currentNicknameProvider.notifier).state = newNick;
          debugLog('🔍 [LOGIN] Nick actualizado en provider: $newNick');
        }
      };
      ircService.addNickChangeListener(_nickChangeListener!);
      
      await ircService.connect(
        host: host,
        port: port, // Siempre usar el puerto IRC real (6667 o 6697)
        nickname: nick,
        useSSL: useSSL,
      );

      // globalLog('🔵 [LOGIN] connect() returned successfully');
      
      // Si hay contraseña (campo de identificación), enviar IDENTIFY al bot "nick" tras conectar
      final identifyPassword = _passwordController.text.trim();
      if (identifyPassword.isNotEmpty) {
        // Esperar a que la conexión y el nick estén confirmados en el servidor
        await Future.delayed(const Duration(milliseconds: 3000));
        ircService.identifyNick(identifyPassword);
      }
      
      // Actualizar el provider con el nick inicial (se actualizará automáticamente si el servidor lo modifica)
      ref.read(currentNicknameProvider.notifier).state = nick;
      // Subir avatar GIF al servidor automáticamente para que otros usuarios lo vean (sin pedir nada al usuario)
      ref.read(globalAvatarGifProvider.notifier).syncGifToServer(nick);
      // globalLog('🔵 [LOGIN] Set nickname in provider');
      
      // Normalizar el nombre del canal antes de guardarlo
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
      
      // Verificar si hay canales guardados para autojoin (cuando se cambia de servidor)
      final autoJoinChannels = ref.read(autoJoinChannelsProvider);
      final currentChannelFromProvider = ref.read(currentChannelProvider);
      final channelsToRestore = autoJoinChannels.isNotEmpty
          ? autoJoinChannels
          : <String>[normalizedChannel];
      final identifyPasswordForRecovery =
          _identifyWithNick ? _passwordController.text.trim() : null;

      ircService.configureSessionRecovery(
        autoReconnectEnabled: _autoReconnectEnabled,
        identifyPassword: identifyPasswordForRecovery,
        channelsToRestore: channelsToRestore,
      );
      
      debugLog('🔍 [CONNECT] Canales para autojoin: $autoJoinChannels');
      debugLog('🔍 [CONNECT] Canal actual desde provider: $currentChannelFromProvider');
      
      if (autoJoinChannels.isNotEmpty) {
        // Si hay canales guardados, hacer JOIN a todos ellos después de conectarse
        debugLog('🔍 [AUTOJOIN] ✅ Hay ${autoJoinChannels.length} canales para autojoin: $autoJoinChannels');
        
        // Esperar a que la conexión esté completamente establecida antes de hacer JOIN
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted && ircService.isConnected) {
            // Hacer JOIN a cada canal con un pequeño delay
            for (int i = 0; i < autoJoinChannels.length; i++) {
              final channelToJoin = autoJoinChannels[i];
              Future.delayed(Duration(milliseconds: 500 + (i * 300)), () {
                if (mounted && ircService.isConnected) {
                  debugLog('🔍 [AUTOJOIN] Uniéndose a canal: $channelToJoin');
                  ircService.joinChannel(channelToJoin);
                }
              });
            }
            
            // Establecer el canal actual como el primero de la lista (o el que estaba antes)
            final channelToSet = currentChannelFromProvider ?? autoJoinChannels.first;
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                ref.read(currentChannelProvider.notifier).state = channelToSet;
                debugLog('🔍 [AUTOJOIN] Canal actual establecido: $channelToSet');
              }
            });
          }
        });
      } else {
        // Si no hay canales guardados, usar el canal del formulario (comportamiento normal)
        ref.read(currentChannelProvider.notifier).state = normalizedChannel;
        debugLog('🔍 [CONNECT] Usando canal del formulario: $normalizedChannel');
      }
      // globalLog('🔵 [LOGIN] Set channel in provider: "$channel" -> normalized: "$normalizedChannel"');

      // globalLog('🔵 [LOGIN] About to navigate to ChatScreen');
      
      if (mounted) {
        final identifyPassword = _identifyWithNick ? _passwordController.text.trim() : null;
        await _saveLoginPrefs(nick, normalizedChannel, _identifyWithNick, identifyPassword: identifyPassword);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_prefAutoReconnect, _autoReconnectEnabled);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ChatScreen(),
          ),
        );
      } else {
        // globalLog('❌ [LOGIN] Widget not mounted, cannot navigate');
      }
    } catch (e) {
      // globalLog('❌ [LOGIN] EXCEPTION: $e');
      // globalLog('❌ [LOGIN] STACK: $stack');
      String errorMessage = 'Error de conexión: $e';
      
      // Mensajes de error más amigables
      if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        errorMessage = 'No se pudo conectar al servidor. Verifica el host y puerto.';
      } else if (e.toString().contains('TimeoutException')) {
        errorMessage = 'Tiempo de espera agotado. El servidor no respondió.';
      } else if (e.toString().contains('TlsException') || e.toString().contains('SSL')) {
        errorMessage = 'Error SSL/TLS. Verifica que el servidor soporte conexiones seguras en el puerto 6697.';
      }
      
      setState(() => _errorMessage = errorMessage);
      setState(() {
        _isLoading = false;
        _isAutoJoining = false; // Resetear flag de autojoin
      });
    }
    
    // globalLog('========================================');
    // globalLog('🔵 [LOGIN] _connect() method finished');
    // globalLog('========================================');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    // Si está en proceso de autojoin, mostrar pantalla de carga simple
    if (_isAutoJoining && _isLoading) {
      return Scaffold(
        backgroundColor: appTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(appTheme.primary),
              ),
              const SizedBox(height: 24),
              Text(
                'Conectando automáticamente...',
                style: TextStyle(
                  color: appTheme.textPrimary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Canal: ${_channelController.text}',
                style: TextStyle(
                  color: appTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(PlatformUtils.isWeb ? 'GlobalChat Web Script' : 'GlobalChat Script'),
        backgroundColor: appTheme.primary,
        foregroundColor: appTheme.textPrimary,
        elevation: 2,
        actions: [
          // Mostrar versión
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: appTheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: appTheme.textPrimary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  _appVersion,
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.palette),
            tooltip: 'Cambiar tema',
            color: appTheme.textPrimary,
            onPressed: () => _showThemeSelector(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              appTheme.primary.withValues(alpha: 0.15),
              appTheme.secondary.withValues(alpha: 0.12),
              appTheme.accent.withValues(alpha: 0.08),
              appTheme.background,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_autoConnectCountdown != null && !_autoConnectCancelled)
              _buildAutoConnectBanner(appTheme),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 8,
              color: appTheme.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      appTheme.background,
                      appTheme.background.withValues(alpha: 0.95),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AnimatedLogo(appTheme: appTheme),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              PlatformUtils.isWeb ? 'GlobalChat Web Script' : 'GlobalChat Script',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: appTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cliente avanzado para GlobalChat IRC Network',
                              textAlign: TextAlign.left,
                              style: TextStyle(
                                fontSize: 13,
                                color: appTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
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
                              color: appTheme.primary.withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showThemeSelector(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.palette,
                                size: 32,
                                color: appTheme.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Selector de servidor
                  SizedBox(
                    height: 56,
                    child: DropdownButtonFormField<ServerProfile>(
                      initialValue: _selectedServer,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Servidor',
                        prefixIcon: Icon(Icons.language, color: appTheme.primary),
                        labelStyle: TextStyle(color: appTheme.primary),
                        filled: true,
                        fillColor: appTheme.surface.withValues(alpha: 0.9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withValues(alpha: 0.6), width: 1.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withValues(alpha: 0.4), width: 1),
                        ),
                      ),
                      dropdownColor: appTheme.surface,
                      style: TextStyle(color: appTheme.textPrimary),
                      items: ServerProfile.defaultGlobalChatProfiles.map((profile) {
                        return DropdownMenuItem<ServerProfile>(
                          value: profile,
                          child: Row(
                            children: [
                              Icon(
                                profile.useSSL ? Icons.lock : Icons.lock_open,
                                size: 18,
                                color: profile.useSSL ? Colors.green : appTheme.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  profile.name,
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontWeight: profile.isDefault ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (ServerProfile? newProfile) {
                        if (newProfile != null) {
                          setState(() {
                            _selectedServer = newProfile;
                            _updateServerFields(newProfile);
                          });
                          _checkServerStatus();
                        }
                      },
                    ),
                  ),
                  if (_serverStatus != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          _serverStatus == 'checking'
                              ? Icons.schedule
                              : _serverStatus == 'available'
                                  ? Icons.check_circle
                                  : Icons.cancel,
                          size: 18,
                          color: _serverStatus == 'checking'
                              ? appTheme.textSecondary
                              : _serverStatus == 'available'
                                  ? Colors.green
                                  : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _serverStatus == 'checking'
                              ? 'Comprobando servidor…'
                              : _serverStatus == 'available'
                                  ? 'Servidor disponible'
                                  : 'No se pudo conectar',
                          style: TextStyle(
                            fontSize: 12,
                            color: _serverStatus == 'checking'
                                ? appTheme.textSecondary
                                : _serverStatus == 'available'
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  ExpansionTile(
                    initiallyExpanded: _advancedExpanded,
                    onExpansionChanged: (v) => setState(() => _advancedExpanded = v),
                    tilePadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    title: Text(
                      'Opciones avanzadas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: appTheme.primary,
                      ),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 8, bottom: 12),
                        child: Column(
                          children: [
                            TextField(
                              controller: _hostController,
                              onChanged: (_) => _checkServerStatus(),
                              style: TextStyle(color: appTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Host',
                                prefixIcon: Icon(Icons.dns, color: appTheme.primary, size: 20),
                                labelStyle: TextStyle(color: appTheme.primary),
                                filled: true,
                                fillColor: appTheme.surface.withValues(alpha: 0.9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _portController,
                              onChanged: (_) => _checkServerStatus(),
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: appTheme.textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Puerto',
                                prefixIcon: Icon(Icons.numbers, color: appTheme.primary, size: 20),
                                labelStyle: TextStyle(color: appTheme.primary),
                                filled: true,
                                fillColor: appTheme.surface.withValues(alpha: 0.9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _nickController,
                          style: TextStyle(color: appTheme.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Apodo',
                            hintText: 'Escribe tu apodo o usa el generado',
                            helperText: 'Puedes cambiar el apodo generado',
                            helperMaxLines: 2,
                            prefixIcon: Icon(Icons.person, color: appTheme.primary),
                            labelStyle: TextStyle(color: appTheme.primary),
                            hintStyle: TextStyle(color: appTheme.textSecondary),
                            helperStyle: TextStyle(color: appTheme.textSecondary, fontSize: 11),
                            filled: true,
                            fillColor: appTheme.surface.withValues(alpha: 0.9),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: appTheme.primary, width: 2),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: appTheme.primary.withValues(alpha: 0.6), width: 1.5),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: appTheme.primary.withValues(alpha: 0.4), width: 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: TextButton.icon(
                          onPressed: _generateRandomNick,
                          icon: Icon(Icons.refresh, size: 18, color: appTheme.primary),
                          label: Text('Otro apodo', style: TextStyle(fontSize: 12, color: appTheme.primary)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Checkbox para identificar con nick registrado
                  Row(
                    children: [
                      Checkbox(
                        value: _identifyWithNick,
                        onChanged: (value) {
                          setState(() {
                            _identifyWithNick = value ?? false;
                            if (!_identifyWithNick) {
                              _passwordController.clear();
                            }
                          });
                        },
                        activeColor: appTheme.primary,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _identifyWithNick = !_identifyWithNick;
                              if (!_identifyWithNick) {
                                _passwordController.clear();
                              }
                            });
                          },
                          child: Text(
                            'Identificarse con nick registrado',
                            style: TextStyle(
                              color: appTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Reconectar automáticamente al abrir la app (opt-in)
                  Row(
                    children: [
                      Checkbox(
                        value: _autoReconnectEnabled,
                        onChanged: (value) async {
                          final v = value ?? false;
                          setState(() => _autoReconnectEnabled = v);
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool(_prefAutoReconnectEnabled, v);
                        },
                        activeColor: appTheme.primary,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final v = !_autoReconnectEnabled;
                            setState(() => _autoReconnectEnabled = v);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool(_prefAutoReconnectEnabled, v);
                          },
                          child: Text(
                            'Reconectar automáticamente al abrir la app',
                            style: TextStyle(
                              color: appTheme.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Campo de contraseña (solo visible si se marca el checkbox)
                  if (_identifyWithNick) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(color: appTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Contraseña del nick',
                        hintText: 'Contraseña para identificar el nick',
                        prefixIcon: Icon(Icons.lock, color: appTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                            color: appTheme.primary.withValues(alpha: 0.7),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                        ),
                        labelStyle: TextStyle(color: appTheme.primary),
                        hintStyle: TextStyle(color: appTheme.textSecondary),
                        helperText: 'Se identificará automáticamente con NickServ al conectar',
                        helperStyle: TextStyle(color: appTheme.textSecondary, fontSize: 11),
                        filled: true,
                        fillColor: appTheme.surface.withValues(alpha: 0.9),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withValues(alpha: 0.6), width: 1.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withValues(alpha: 0.4), width: 1),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (PlatformUtils.isWeb) ...[
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: appTheme.surface.withValues(alpha: 0.9),
                        border: Border.all(
                          color: appTheme.primary.withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          Switch(
                            value: _geolocationEnabled,
                            onChanged: (value) {
                              setState(() {
                                _geolocationEnabled = value;
                              });
                              if (value) {
                                _applyGeoIpChannelsFromToggle();
                              } else {
                                _clearGeoIpChannelsFromToggle();
                              }
                            },
                            activeThumbColor: appTheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Usar ubicación (GeoIP)',
                                  style: TextStyle(
                                    color: appTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _geolocationEnabled
                                      ? 'Activado: sugerirá servidor y canales según tu país/ciudad.'
                                      : 'Desactivado: no usará ubicación; elige servidor y canal manualmente.',
                                  style: TextStyle(
                                    color: appTheme.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _ChannelSelector(
                    controller: _channelController,
                    channels: _channels,
                    loadingChannels: _loadingChannels,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _confirmOver14,
                    onChanged: (value) => setState(() => _confirmOver14 = value ?? false),
                    title: Text(
                      'Confirmo que soy mayor de 14 años',
                      style: TextStyle(
                        color: appTheme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    activeColor: appTheme.primary,
                    checkColor: appTheme.textPrimary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  CheckboxListTile(
                    value: _acceptRules,
                    onChanged: (value) => setState(() => _acceptRules = value ?? false),
                    title: Wrap(
                      children: [
                        Text(
                          'Acepto las ',
                          style: TextStyle(color: appTheme.textPrimary, fontSize: 14),
                        ),
                        GestureDetector(
                          onTap: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RulesScreen())); },
                          child: Text(
                            'reglas del canal/red',
                            style: TextStyle(
                              color: appTheme.primary,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    activeColor: appTheme.primary,
                    checkColor: appTheme.textPrimary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: () => _launchUrl('https://globalchat.org'),
                        child: Text('¿Primera vez?', style: TextStyle(fontSize: 12, color: appTheme.primary)),
                      ),
                      Text(' · ', style: TextStyle(color: appTheme.textSecondary, fontSize: 12)),
                      TextButton(
                        onPressed: () => _launchUrl('https://registro-chan.globalchat.org'),
                        child: Text('Registro de nick', style: TextStyle(fontSize: 12, color: appTheme.primary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  if (_errorMessage != null) const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _enterAsGuest,
                          icon: Icon(Icons.person_outline, size: 20, color: appTheme.primary),
                          label: const Text('Entrar como invitado'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: appTheme.primary,
                            side: BorderSide(color: appTheme.primary),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_isLoading || !_confirmOver14 || !_acceptRules) ? null : _connect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: appTheme.primary,
                              disabledBackgroundColor: Colors.grey,
                              foregroundColor: appTheme.textPrimary,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(appTheme.textPrimary),
                                    ),
                                  )
                                : Text(
                                    'Conectar',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: appTheme.textPrimary,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        ),
      ),
    ),
    ],
  ),
  ),
  );
  }

  /// Banner de cuenta atrás antes de auto-conectar; permite cancelar para configurar.
  Widget _buildAutoConnectBanner(AppTheme appTheme) {
    return Material(
      color: appTheme.primary.withValues(alpha: 0.9),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.schedule, color: appTheme.textPrimary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _autoConnectCountdown != null && _autoConnectCountdown! > 0
                      ? 'Conectando automáticamente en $_autoConnectCountdown s...'
                      : 'Conectando...',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  _autoConnectTimer?.cancel();
                  _autoConnectTimer = null;
                  setState(() {
                    _autoConnectCountdown = null;
                    _autoConnectCancelled = true;
                  });
                },
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: appTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    currentTheme.primary,
                    currentTheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.palette,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Seleccionar Tema',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: AppTheme.themes.length,
            itemBuilder: (context, index) {
              final theme = AppTheme.themes[index];
              final isSelected = theme.name == currentTheme.name;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? theme.primary : Colors.grey.withValues(alpha: 0.3),
                    width: isSelected ? 2.5 : 1,
                  ),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            theme.primary.withValues(alpha: 0.1),
                            theme.secondary.withValues(alpha: 0.1),
                          ],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.primary,
                          theme.secondary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: theme.accent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    theme.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      fontSize: 16,
                      color: isSelected ? theme.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 18,
                          ),
                        )
                      : null,
                  onTap: () {
                    ref.read(themeProvider.notifier).setTheme(theme);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// Widget animado para el logo de GlobalChat
class _AnimatedLogo extends StatefulWidget {
  final AppTheme appTheme;
  
  const _AnimatedLogo({required this.appTheme});
  
  @override
  State<_AnimatedLogo> createState() => _AnimatedLogoState();
}

class _AnimatedLogoState extends State<_AnimatedLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.9,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: -0.05,
      end: 0.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Image.network(
                  'https://registro-chan.globalchat.org/gc/logo.png',
                  height: 200,
                  width: 200,
                  fit: BoxFit.contain,
                  // En web, usar WebHtmlElementStrategy.prefer para evitar problemas de CORS
                  // Esto intenta usar elementos HTML <img> que no tienen las mismas restricciones CORS
                  webHtmlElementStrategy: PlatformUtils.isWeb 
                      ? WebHtmlElementStrategy.prefer 
                      : WebHtmlElementStrategy.never,
                  errorBuilder: (context, error, stackTrace) {
                    // Si falla la carga, mostrar el icono con colores del tema
                    return Container(
                      height: 200,
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            widget.appTheme.primary,
                            widget.appTheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.appTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chat_bubble,
                        size: 80,
                        color: widget.appTheme.textPrimary,
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      padding: const EdgeInsets.all(16),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.appTheme.primary),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Widget personalizado para seleccionar canal con dropdown
class _ChannelSelector extends StatefulWidget {
  final TextEditingController controller;
  final List<ChannelInfo> channels;
  final bool loadingChannels;
  final dynamic appTheme;

  const _ChannelSelector({
    required this.controller,
    required this.channels,
    required this.loadingChannels,
    required this.appTheme,
  });

  @override
  State<_ChannelSelector> createState() => _ChannelSelectorState();
}

class _ChannelSelectorState extends State<_ChannelSelector> {
  final FocusNode _focusNode = FocusNode();
  List<ChannelInfo> _filteredChannels = [];
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _updateFilteredChannels();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(_ChannelSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.channels != oldWidget.channels) {
      _updateFilteredChannels();
    }
  }

  void _updateFilteredChannels() {
    final query = widget.controller.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        // Mostrar todos los canales disponibles; el scroll del ListView
        // se encargará de que la lista siga siendo usable.
        _filteredChannels = widget.channels.toList();
      } else {
        _filteredChannels = widget.channels.where((channel) {
          return channel.name.toLowerCase().contains(query) ||
              channel.topic.toLowerCase().contains(query);
        }).toList();
      }
      // debugLog('🔍 [DEBUG] _updateFilteredChannels: ${_filteredChannels.length} canales filtrados de ${widget.channels.length} totales');
    });
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.channels.isNotEmpty) {
      // Si el campo está vacío, mostrar todos los canales automáticamente
      if (widget.controller.text.isEmpty) {
        setState(() {
          // Sin límite artificial: se pueden recorrer todos los canales
          _filteredChannels = widget.channels.toList();
        });
      }
      _showDropdownOverlay();
    } else {
      _hideDropdownOverlay();
    }
  }

  void _onTextChanged() {
    _updateFilteredChannels();
    
    // Si el campo está vacío y tiene foco, asegurar que el dropdown esté visible con todos los canales
    if (widget.controller.text.trim().isEmpty && _focusNode.hasFocus && widget.channels.isNotEmpty) {
      if (!_showDropdown) {
        _showDropdownOverlay();
      }
    }
  }

  void _showDropdownOverlay() {
    // Al abrir manualmente el desplegable queremos poder ver TODOS los canales,
    // incluso si ya hay un canal escrito en el TextField (para poder cambiarlo).
    // El filtrado por texto se seguirá aplicando solo cuando el usuario escriba.
    if (widget.controller.text.trim().isEmpty) {
      _updateFilteredChannels();
    } else {
      setState(() {
        _filteredChannels = widget.channels.toList();
      });
    }
    
    // debugLog('🔍 [DEBUG] _showDropdownOverlay: ${_filteredChannels.length} canales, ${widget.channels.length} totales');
    
    // Usar showModalBottomSheet en lugar de overlay personalizado
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: widget.appTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.appTheme.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar Canal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.appTheme.primary,
                  ),
                ),
              ),
              // Campo de texto para escribir canal personalizado
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Builder(
                  builder: (context) {
                    final customChannelController = TextEditingController();
                    return TextField(
                      controller: customChannelController,
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Escribe un canal (ej: #micanal)',
                        hintStyle: TextStyle(color: widget.appTheme.textSecondary),
                        prefixIcon: Icon(Icons.edit, color: widget.appTheme.primary),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.check_circle, color: widget.appTheme.primary),
                          onPressed: () {
                            final value = customChannelController.text.trim();
                            if (value.isNotEmpty) {
                              String channelName = value;
                              if (!channelName.startsWith('#')) {
                                channelName = '#$channelName';
                              }
                              widget.controller.text = channelName;
                              widget.controller.selection = TextSelection(
                                baseOffset: widget.controller.text.length,
                                extentOffset: widget.controller.text.length,
                              );
                              Navigator.pop(context);
                              _focusNode.unfocus();
                            }
                          },
                        ),
                        filled: true,
                        fillColor: widget.appTheme.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.appTheme.primary.withValues(alpha: 0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.appTheme.primary.withValues(alpha: 0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.appTheme.primary, width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: TextStyle(color: widget.appTheme.textPrimary),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          String channelName = value.trim();
                          if (!channelName.startsWith('#')) {
                            channelName = '#$channelName';
                          }
                          widget.controller.text = channelName;
                          widget.controller.selection = TextSelection(
                            baseOffset: widget.controller.text.length,
                            extentOffset: widget.controller.text.length,
                          );
                          Navigator.pop(context);
                          _focusNode.unfocus();
                        }
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Canales disponibles',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: widget.appTheme.textSecondary,
                  ),
                ),
              ),
              Flexible(
                child: _filteredChannels.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No se encontraron canales',
                          style: TextStyle(color: widget.appTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredChannels.length,
                        itemBuilder: (BuildContext context, int index) {
                          final option = _filteredChannels[index];
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: widget.appTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: widget.appTheme.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${option.users}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.appTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: option.topic.isNotEmpty
                                ? Text(
                                    option.topic.length > 60
                                        ? '${option.topic.substring(0, 60)}...'
                                        : option.topic,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: widget.appTheme.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )
                                : null,
                            onTap: () {
                              // debugLog('🔍 [DEBUG] ✅✅✅✅✅ TAP DETECTADO en canal: ${option.name}');
                              widget.controller.text = option.name;
                              widget.controller.selection = TextSelection(
                                baseOffset: widget.controller.text.length,
                                extentOffset: widget.controller.text.length,
                              );
                              // debugLog('🔍 [DEBUG] Controlador actualizado: "${widget.controller.text}"');
                              Navigator.pop(context);
                              _focusNode.unfocus();
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      setState(() {
        _showDropdown = false;
      });
    });
    
    setState(() {
      _showDropdown = true;
    });
  }

  void _hideDropdownOverlay() {
    // Con showModalBottomSheet, se cierra automáticamente con Navigator.pop
    setState(() {
      _showDropdown = false;
    });
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        style: TextStyle(color: widget.appTheme.textPrimary),
        decoration: InputDecoration(
          labelText: 'Canal',
          hintText: widget.loadingChannels 
              ? 'Cargando canales...' 
              : 'Escribe o selecciona un canal',
          labelStyle: TextStyle(color: widget.appTheme.primary),
          hintStyle: TextStyle(color: widget.appTheme.textSecondary),
          filled: true,
          fillColor: widget.appTheme.surface.withValues(alpha: 0.9),
          prefixIcon: widget.loadingChannels
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(widget.appTheme.primary),
                    ),
                  ),
                )
              : Icon(Icons.tag, color: widget.appTheme.primary),
          suffixIcon: widget.channels.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    _showDropdown ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    color: widget.appTheme.primary,
                  ),
                  onPressed: () {
                    if (_showDropdown) {
                      _hideDropdownOverlay();
                      _focusNode.unfocus();
                    } else {
                      _focusNode.requestFocus();
                      _showDropdownOverlay();
                    }
                  },
                )
              : null,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.appTheme.primary, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.appTheme.primary.withValues(alpha: 0.6), width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.appTheme.primary.withValues(alpha: 0.4), width: 1),
          ),
        ),
        onTap: () {
          // debugLog('🔍 [DEBUG] onTap del TextField: ${widget.channels.length} canales disponibles');
          if (widget.channels.isNotEmpty) {
            // Si el campo está vacío, asegurar que se muestren todos los canales
            if (widget.controller.text.trim().isEmpty) {
              _updateFilteredChannels();
            }
            // Mostrar el dropdown siempre
            _showDropdownOverlay();
          } else {
            // debugLog('🔍 [DEBUG] ⚠️  No hay canales disponibles aún');
          }
        },
    );
  }
}
