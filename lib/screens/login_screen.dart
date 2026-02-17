import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:math';
// Conditional import for web URL parameters
import 'dart:html' if (dart.library.io) '../utils/html_stub.dart' as html;
import '../providers/irc_provider.dart';
import '../providers/theme_provider.dart';
import '../models/app_theme.dart';
import '../models/channel_info.dart';
import '../models/server_profile.dart';
import 'chat_screen.dart';
import '../main.dart' show globalLog;
import '../utils/platform_utils.dart';
import '../services/geoip_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

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
  
  // Lista de canales prohibidos que no se mostrarán en el combo
  static const List<String> _prohibitedChannels = ['#opers', '#services'];

  @override
  void initState() {
    super.initState();
    
    // Log muy temprano para verificar que se ejecuta
    debugPrint('🔍 [INIT] LoginScreen initState iniciado');
    print('🔍 [INIT] LoginScreen initState iniciado - PRINT');
    if (PlatformUtils.isWeb) {
      try {
        html.window.console.log('🔍 [INIT] LoginScreen initState iniciado - CONSOLE');
      } catch (e) {
        // Ignorar si no está disponible
      }
    }
    
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
      print('🔍 [INIT] PlatformUtils.isWeb = true, leyendo parámetros de URL');
      try {
        // Usar dart:html directamente para leer la URL (más confiable en Flutter web)
        final window = html.window;
        final location = window.location;
        final fullUrl = location.href ?? '';
        
        print('🔍 [URL] location.href: "$fullUrl"');
        print('🔍 [URL] location.search: "${location.search}"');
        print('🔍 [URL] location.hash: "${location.hash}"');
        
        if (fullUrl.isNotEmpty) {
          final fullUri = Uri.parse(fullUrl);
          print('🔍 [URL] fullUri.queryParameters: ${fullUri.queryParameters}');
          
          // Leer parámetros del query string
          final nickParam = fullUri.queryParameters['nick'];
          final channelParam = fullUri.queryParameters['channel'];
          final autoJoinParam = fullUri.queryParameters['autojoin'];
          // Nuevo parámetro: permite controlar el autojoin al canal oficial #globalchat
          // Ejemplo: ?joinchanneloficial=false  -> NO autojinear a #globalchat
          //          ?joinchanneloficial=true   -> autojinear (por defecto)
          final joinOficialParam = fullUri.queryParameters['joinchanneloficial'];
          
          if (nickParam != null && nickParam.trim().isNotEmpty) {
            // Limpiar el nick: eliminar espacios y guiones al final
            var cleanNick = nickParam.trim();
            while (cleanNick.endsWith('_')) {
              cleanNick = cleanNick.substring(0, cleanNick.length - 1).trim();
            }
            urlNick = cleanNick;
            print('🔍 [URL] ✅ Nick leído: "$nickParam" -> Limpio: "$urlNick"');
          }
          
          // Leer canal de query string
          if (channelParam != null) {
            final trimmed = channelParam.trim();
            if (trimmed.isNotEmpty && trimmed != '=') {
              urlChannel = trimmed;
              print('🔍 [URL] ✅ Canal leído: "$urlChannel"');
            } else {
              print('🔍 [URL] ⚠️ Canal vacío o solo "=", channelParam="$channelParam"');
            }
          } else {
            print('🔍 [URL] ⚠️ channelParam es null');
          }
          
          // Leer parámetro autojoin
          if (autoJoinParam != null) {
            final autoJoinValue = autoJoinParam.toLowerCase().trim();
            autoJoin = autoJoinValue == 'true' || 
                       autoJoinValue == '1' || 
                       autoJoinValue == 'yes';
            print('🔍 [URL] ✅ autoJoin leído: "$autoJoinParam" -> autoJoin=$autoJoin');
          }

          // Leer parámetro joinchanneloficial (controla autojoin a #globalchat)
          if (joinOficialParam != null) {
            final value = joinOficialParam.toLowerCase().trim();
            if (value == 'false' || value == '0' || value == 'no') {
              joinChannelOficialFromUrl = false;
            } else if (value == 'true' || value == '1' || value == 'yes') {
              joinChannelOficialFromUrl = true;
            }
            print('🔍 [URL] ✅ joinchanneloficial leído: "$joinOficialParam" -> $joinChannelOficialFromUrl');
          }
        } else {
          // Fallback a Uri.base si location.href está vacío
          final uri = Uri.base;
          print('🔍 [URL] Fallback a Uri.base: ${Uri.base}');
          print('🔍 [URL] Uri.base.queryParameters: ${uri.queryParameters}');
          
          final nickParam = uri.queryParameters['nick'];
          final channelParam = uri.queryParameters['channel'];
          final autoJoinParam = uri.queryParameters['autojoin'];
          final joinOficialParam = uri.queryParameters['joinchanneloficial'];
          
          if (nickParam != null && nickParam.trim().isNotEmpty) {
            // Limpiar el nick: eliminar espacios y guiones al final
            var cleanNick = nickParam.trim();
            while (cleanNick.endsWith('_')) {
              cleanNick = cleanNick.substring(0, cleanNick.length - 1).trim();
            }
            urlNick = cleanNick;
            print('🔍 [URL] ✅ Nick leído de Uri.base: "$nickParam" -> Limpio: "$urlNick"');
          }
          
          if (channelParam != null) {
            final trimmed = channelParam.trim();
            if (trimmed.isNotEmpty && trimmed != '=') {
              urlChannel = trimmed;
              print('🔍 [URL] ✅ Canal leído de Uri.base: "$urlChannel"');
            }
          }
          
          if (autoJoinParam != null) {
            final autoJoinValue = autoJoinParam.toLowerCase().trim();
            autoJoin = autoJoinValue == 'true' || 
                       autoJoinValue == '1' || 
                       autoJoinValue == 'yes';
            print('🔍 [URL] ✅ autoJoin leído de Uri.base: "$autoJoinParam" -> autoJoin=$autoJoin');
          }

          if (joinOficialParam != null) {
            final value = joinOficialParam.toLowerCase().trim();
            if (value == 'false' || value == '0' || value == 'no') {
              joinChannelOficialFromUrl = false;
            } else if (value == 'true' || value == '1' || value == 'yes') {
              joinChannelOficialFromUrl = true;
            }
            print('🔍 [URL] ✅ joinchanneloficial leído de Uri.base: "$joinOficialParam" -> $joinChannelOficialFromUrl');
          }
        }
        
        // Debug: verificar que se leyeron los parámetros
        print('🔍 [URL] Parámetros finales - nick: $urlNick, channel: $urlChannel, autojoin: $autoJoin, joinchanneloficial: $joinChannelOficialFromUrl');
      } catch (e) {
        print('🔍 [URL] Error leyendo URL: $e');
      }
    }
    
    // Generar un nickname aleatorio: GlobalChat-XXXXX (número aleatorio de 4-5 dígitos)
    // O usar el de la URL si está presente
    final random = Random();
    final randomNumber = random.nextInt(90000) + 10000; // Número entre 10000 y 99999
    // Asegurarse de que el nick de la URL esté limpio (sin guiones al final)
    final cleanUrlNick = urlNick != null ? urlNick.trim() : null;
    final defaultNick = cleanUrlNick ?? 'GlobalChat-$randomNumber';
    _nickController = TextEditingController(text: defaultNick);
    print('🔍 [LOGIN] NickController inicializado con: "$defaultNick"');
    
    // Aplicar configuración de auto-join al canal oficial #globalchat si viene en la URL
    // Solo tiene efecto en web
    if (PlatformUtils.isWeb && joinChannelOficialFromUrl != null) {
      final ircService = ref.read(ircServiceProvider);
      ircService.setAutoJoinOfficialGlobalChat(joinChannelOficialFromUrl);
      print('🌐 [LOGIN] joinchanneloficial aplicado al IRCService: $joinChannelOficialFromUrl');
    }

    // Pre-llenar el canal si viene en la URL
    if (urlChannel != null && urlChannel.trim().isNotEmpty) {
      String channel = urlChannel.trim();
      // Asegurar que empiece con #
      if (!channel.startsWith('#')) {
        channel = '#$channel';
      }
      _channelController.text = channel;
      print('🔍 [URL] ✅ Canal aplicado al controlador: $channel');
      print('🔍 [URL] Verificación - _channelController.text = "${_channelController.text}"');
    } else {
      print('🔍 [URL] ⚠️ No se aplicó canal - urlChannel: $urlChannel');
    }
    
    // Leer servidor seleccionado del provider (si se cambió desde el AppBar)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Esperar un momento para asegurar que el provider se haya inicializado
      await Future.delayed(const Duration(milliseconds: 100));
      
      // En web: obtener ciudad/región por GeoIP y añadir join al canal de la ciudad/región
      if (PlatformUtils.isWeb) {
        try {
          final loc = await GeoIPService.getCityRegion();
          if (loc != null && mounted) {
            final city = loc['city'];
            final region = loc['region'];
            final channelCity = GeoIPService.cityRegionToChannelName(city, region);
            final hasUrlChannel = urlChannel != null && urlChannel!.trim().isNotEmpty;
            final currentChannelStored = ref.read(currentChannelProvider);
            final autoJoinChannels = ref.read(autoJoinChannelsProvider);
            if (!hasUrlChannel && (currentChannelStored == null || currentChannelStored.isEmpty) && autoJoinChannels.isEmpty) {
              _channelController.text = channelCity;
              ref.read(currentChannelProvider.notifier).state = channelCity;
              ref.read(autoJoinChannelsProvider.notifier).state = [channelCity];
              print('🌍 [GEOIP] Canal por ciudad/región (sin canal previo): $channelCity');
            } else {
              final urlCh = urlChannel?.trim() ?? '';
              final mainChannel = hasUrlChannel && urlCh.isNotEmpty
                  ? (urlCh.startsWith('#') ? urlCh : '#$urlCh')
                  : (currentChannelStored ?? _channelController.text.trim());
              final mainNorm = mainChannel.isNotEmpty ? (mainChannel.startsWith('#') ? mainChannel : '#$mainChannel') : null;
              final toJoin = <String>[];
              if (mainNorm != null && mainNorm != channelCity) toJoin.add(mainNorm);
              if (!toJoin.contains(channelCity)) toJoin.add(channelCity);
              ref.read(autoJoinChannelsProvider.notifier).state = toJoin;
              if (mainNorm != null) {
                ref.read(currentChannelProvider.notifier).state = mainNorm;
                _channelController.text = mainNorm;
              }
              print('🌍 [GEOIP] Añadido join a canal ciudad/región: $channelCity (canales: $toJoin)');
            }
          }
        } catch (e) {
          print('🌍 [GEOIP] Error obteniendo ciudad/región: $e');
        }
      }
      
      final selectedServerProfile = ref.read(currentServerProfileProvider);
      final currentChannel = ref.read(currentChannelProvider);
      final currentNick = ref.read(currentNicknameProvider);
      final autoJoinChannels = ref.read(autoJoinChannelsProvider);
      
      print('🔍 [LOGIN] ========== INICIO LOGIN ==========');
      print('🔍 [LOGIN] Estado inicial - servidor: ${selectedServerProfile?.name ?? "null"}');
      print('🔍 [LOGIN] Servidor host: ${selectedServerProfile?.host ?? "null"}, port: ${selectedServerProfile?.port ?? "null"}');
      print('🔍 [LOGIN] Nick: $currentNick');
      print('🔍 [LOGIN] Canal: $currentChannel');
      print('🔍 [LOGIN] Canales autojoin: $autoJoinChannels');
      print('🔍 [LOGIN] Canal desde URL: $urlChannel');
      print('🔍 [LOGIN] ===================================');
      
      // Verificar si hay datos guardados para autojoin (viene de cambio de servidor)
      final hasAutoJoinData = currentNick != null && currentNick.isNotEmpty && 
                             (currentChannel != null && currentChannel.isNotEmpty || autoJoinChannels.isNotEmpty);
      
      if (selectedServerProfile != null) {
        print('🔍 [LOGIN] ✅ Servidor seleccionado desde provider: ${selectedServerProfile.name}');
        print('🔍 [LOGIN] Servidor host: ${selectedServerProfile.host}, port: ${selectedServerProfile.port}');
        _selectedServer = selectedServerProfile;
        _updateServerFields(selectedServerProfile);
        
        // Verificar que los campos se actualizaron correctamente
        print('🔍 [LOGIN] Campos actualizados - host: ${_hostController.text}, port: ${_portController.text}');
        
        // Obtener el canal actual si existe (solo si no hay canal de URL)
        if (urlChannel == null || urlChannel.isEmpty) {
          if (currentChannel != null && currentChannel.isNotEmpty) {
            _channelController.text = currentChannel;
            print('🔍 [LOGIN] Canal actual desde provider: $currentChannel');
          } else if (autoJoinChannels.isNotEmpty) {
            // Si no hay canal actual pero hay canales para autojoin, usar el primero
            _channelController.text = autoJoinChannels.first;
            print('🔍 [LOGIN] Usando primer canal de autojoin: ${autoJoinChannels.first}');
          }
        } else {
          print('🔍 [LOGIN] Canal de URL tiene prioridad, no se sobrescribe con provider');
        }
        
        // Obtener el nick del provider si está disponible (solo si no hay nick de URL)
        if ((urlNick == null || urlNick.isEmpty) && currentNick != null && currentNick.isNotEmpty) {
          _nickController.text = currentNick;
          print('🔍 [LOGIN] Nick actual desde provider: $currentNick');
        } else if (urlNick != null && urlNick.isNotEmpty) {
          print('🔍 [LOGIN] Nick de URL tiene prioridad, no se sobrescribe con provider');
        }
        
        // Hacer autojoin automáticamente cuando se cambia de servidor
        // PERO solo si NO viene autojoin desde la URL (para evitar doble conexión)
        if (hasAutoJoinData && !(autoJoin && PlatformUtils.isWeb)) {
          print('🔍 [AUTOJOIN] ✅ Condiciones cumplidas para autojoin: servidor=${selectedServerProfile.name}, nick=$currentNick, canales=$autoJoinChannels');
          
          // Esperar un momento para que los campos se actualicen
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (!mounted) return;
            
            final host = _hostController.text.trim();
            final portText = _portController.text.trim();
            final port = int.tryParse(portText) ?? 6697;
            final nick = _nickController.text.trim();
            final channel = _channelController.text.trim();
            
            print('🔍 [AUTOJOIN] Verificando campos: host=$host, port=$port, nick=$nick, channel=$channel');
            
            if (host.isNotEmpty && nick.isNotEmpty && channel.isNotEmpty) {
              print('🔍 [AUTOJOIN] ✅ Todos los campos están completos, iniciando conexión...');
              print('🔍 [AUTOJOIN] Auto-uniéndose después de cambiar servidor: host=$host, port=$port, nick=$nick, channel=$channel');
              
              setState(() {
                _isAutoJoining = true;
                _isLoading = true;
              });
              
              try {
                await _connect();
                print('🔍 [AUTOJOIN] ✅ Conexión exitosa después de cambiar servidor');
              } catch (e) {
                print('🔍 [AUTOJOIN] ❌ Error en conexión: $e');
                if (mounted) {
                  setState(() {
                    _errorMessage = 'Error en auto-join: $e';
                    _isLoading = false;
                    _isAutoJoining = false;
                  });
                }
              }
            } else {
              print('🔍 [AUTOJOIN] ⚠️ Campos incompletos - host: ${host.isNotEmpty}, nick: ${nick.isNotEmpty}, channel: ${channel.isNotEmpty}');
            }
          });
        } else {
          if (autoJoin && PlatformUtils.isWeb) {
            print('🔍 [LOGIN] Autojoin desde URL tiene prioridad, no se ejecuta autojoin desde provider');
          } else {
            print('🔍 [LOGIN] No se cumplen condiciones para autojoin - nick: ${currentNick != null && currentNick.isNotEmpty}, canal: ${currentChannel != null && currentChannel.isNotEmpty}, canales autojoin: ${autoJoinChannels.isNotEmpty}');
          }
        }
      } else {
        print('🔍 [LOGIN] No hay servidor seleccionado en el provider, usando selección por GeoIP');
        
        // Si autojoin está activado desde URL y no hay servidor seleccionado, hacer autojoin
        if (autoJoin && PlatformUtils.isWeb && (urlNick != null || urlChannel != null)) {
          print('🔍 [AUTOJOIN_URL] ✅ Autojoin activado desde URL - nick: $urlNick, channel: $urlChannel');
          
          // Asegurar que el canal esté en el controlador (puede venir de URL)
          String? channelToUse = urlChannel;
          if (channelToUse == null || channelToUse.trim().isEmpty) {
            channelToUse = _channelController.text.trim();
          }
          
          if (channelToUse != null && channelToUse.trim().isNotEmpty) {
            // Normalizar el canal
            String finalChannel = channelToUse.trim();
            if (!finalChannel.startsWith('#')) {
              finalChannel = '#$finalChannel';
            }
            _channelController.text = finalChannel;
            print('🔍 [AUTOJOIN_URL] Canal normalizado: $finalChannel');
            
            // Filtrar servidores con puerto 6697 (SSL)
            final sslServers = ServerProfile.defaultGlobalChatProfiles
                .where((profile) => profile.port == 6697 && profile.useSSL)
                .toList();
            
            if (sslServers.isNotEmpty) {
              // Asegurar que el puerto sea 6697
              _portController.text = '6697';
              
              // Detectar ubicación geográfica usando GeoIP y seleccionar servidor
              // Luego conectar automáticamente
              // Primero seleccionar el servidor basado en GeoIP
              await _selectServerByGeoIPFromList(sslServers);
              
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
                  print('🔍 [AUTOJOIN_URL] Intentando conectar: host=$host, port=$port, nick=$nick, channel=$channel');
                  
                  // Mostrar estado de carga para autojoin
                  setState(() {
                    _isAutoJoining = true;
                    _isLoading = true;
                  });
                  
                  // Conectar automáticamente
                  try {
                    await _connect();
                    print('🔍 [AUTOJOIN_URL] ✅ Conexión exitosa');
                  } catch (e) {
                    print('🔍 [AUTOJOIN_URL] ❌ Error en conexión: $e');
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
                  print('🔍 [AUTOJOIN_URL] ⚠️ Campos incompletos - host: ${host.isNotEmpty}, nick: ${nick.isNotEmpty}, channel: ${channel.isNotEmpty}');
                }
              }
            } else {
              // Si no hay servidores SSL, usar selección basada en GeoIP
              await _selectServerByGeoIP();
            }
          } else {
            // Si no hay canal, usar selección basada en GeoIP
            await _selectServerByGeoIP();
          }
        }
      }
    });
    
    _loadChannels();
  }

  /// Seleccionar servidor basado en GeoIP desde una lista específica
  /// América → caliope.globalchat.org
  /// Resto del mundo → otros servidores (ceres, creta, apolo)
  Future<void> _selectServerByGeoIPFromList(List<ServerProfile> sslServers) async {
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
          print('🌎 [GEOIP] Usuario en América, usando Caliope');
        }
      } else if (isAmericas == false) {
        // Si está fuera de América, usar otros servidores (excluyendo caliope)
        final nonAmericasServers = sslServers
            .where((profile) => profile.host != 'caliope.globalchat.org')
            .toList();
        
        if (nonAmericasServers.isNotEmpty) {
          // Seleccionar aleatoriamente entre los servidores no americanos
          final random = Random();
          final selectedIndex = random.nextInt(nonAmericasServers.length);
          selectedServer = nonAmericasServers[selectedIndex];
          if (PlatformUtils.isWeb) {
            print('🌎 [GEOIP] Usuario fuera de América, usando ${selectedServer.host}');
          }
        } else {
          // Fallback si no hay otros servidores
          selectedServer = sslServers.first;
          if (PlatformUtils.isWeb) {
            print('🌎 [GEOIP] No hay servidores disponibles, usando por defecto');
          }
        }
      } else {
        // Si no se puede determinar la ubicación, usar selección aleatoria normal
        final random = Random();
        final selectedIndex = random.nextInt(sslServers.length);
        selectedServer = sslServers[selectedIndex];
        if (PlatformUtils.isWeb) {
          print('🌎 [GEOIP] No se pudo determinar ubicación, usando selección aleatoria');
        }
      }
    } catch (e) {
      // Si hay error en GeoIP, usar selección aleatoria normal
      if (PlatformUtils.isWeb) {
        print('🌎 [GEOIP] Error al detectar ubicación: $e, usando selección aleatoria');
      }
      final random = Random();
      final selectedIndex = random.nextInt(sslServers.length);
      selectedServer = sslServers[selectedIndex];
    }
    
    if (mounted) {
      setState(() {
        _selectedServer = selectedServer ?? sslServers.first;
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
          print('🌎 [GEOIP] Usuario en América, usando Caliope');
        }
      } else if (isAmericas == false) {
        // Si está fuera de América, usar otros servidores (excluyendo caliope)
        final nonAmericasServers = sslServers
            .where((profile) => profile.host != 'caliope.globalchat.org')
            .toList();
        
        if (nonAmericasServers.isNotEmpty) {
          // Seleccionar aleatoriamente entre los servidores no americanos
          final random = Random();
          final selectedIndex = random.nextInt(nonAmericasServers.length);
          selectedServer = nonAmericasServers[selectedIndex];
          if (PlatformUtils.isWeb) {
            print('🌎 [GEOIP] Usuario fuera de América, usando ${selectedServer.host}');
          }
        } else {
          // Fallback si no hay otros servidores
          selectedServer = sslServers.first;
          if (PlatformUtils.isWeb) {
            print('🌎 [GEOIP] No hay servidores disponibles, usando por defecto');
          }
        }
      } else {
        // Si no se puede determinar la ubicación, usar selección aleatoria normal
        final random = Random();
        final selectedIndex = random.nextInt(sslServers.length);
        selectedServer = sslServers[selectedIndex];
        if (PlatformUtils.isWeb) {
          print('🌎 [GEOIP] No se pudo determinar ubicación, usando selección aleatoria');
        }
      }
    } catch (e) {
      // Si hay error en GeoIP, usar selección aleatoria normal
      if (PlatformUtils.isWeb) {
        print('🌎 [GEOIP] Error al detectar ubicación: $e, usando selección aleatoria');
      }
      final random = Random();
      final selectedIndex = random.nextInt(sslServers.length);
      selectedServer = sslServers[selectedIndex];
    }
    
    _selectedServer = selectedServer ?? sslServers.first;
    _updateServerFields(_selectedServer!);
  }

  void _updateServerFields(ServerProfile profile) {
    _hostController.text = profile.host;
    _portController.text = profile.port.toString();
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
          // print('🔍 [DEBUG] Canales cargados: ${_channels.length}');
          for (var channel in _channels.take(5)) {
            // print('🔍 [DEBUG]   - ${channel.name} (${channel.users} usuarios)');
          }
        }
      }
    } catch (e) {
      // print('Error cargando canales: $e');
      setState(() {
        _loadingChannels = false;
      });
    }
  }

  // Cargar información de versión de la app
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
      print('🔍 [LOGIN] App version: $_appVersion');
    } catch (e) {
      print('❌ [LOGIN] Error loading app version: $e');
      // Mantener versión por defecto
    }
  }

  @override
  void dispose() {
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

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text) ?? 6697;
    // Limpiar el nick: eliminar espacios y guiones al final que puedan venir de la URL
    var nick = _nickController.text.trim();
    // Si el nick termina en guion, eliminarlo (puede venir de una conexión anterior)
    while (nick.endsWith('_')) {
      nick = nick.substring(0, nick.length - 1).trim();
    }
    final channel = _channelController.text.trim();
    
    print('🔍 [LOGIN] Nick procesado: "${_nickController.text}" -> "$nick"');

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
          print('🔍 [LOGIN] Nick actualizado en provider: $newNick');
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
      
      // Si se proporcionó una contraseña y se marcó la opción de identificar, identificar el nick
      if (_identifyWithNick && _passwordController.text.trim().isNotEmpty) {
        // globalLog('🔐 [LOGIN] Identificando nick con bot "nick"...');
        // Esperar un poco más para que la conexión se establezca completamente
        // y el servidor procese los mensajes iniciales
        await Future.delayed(const Duration(milliseconds: 2000));
        // globalLog('🔐 [LOGIN] Enviando comando IDENTIFY al bot "nick"...');
        ircService.identifyNick(_passwordController.text.trim());
      }
      
      // Actualizar el provider con el nick inicial (se actualizará automáticamente si el servidor lo modifica)
      ref.read(currentNicknameProvider.notifier).state = nick;
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
      
      print('🔍 [CONNECT] Canales para autojoin: $autoJoinChannels');
      print('🔍 [CONNECT] Canal actual desde provider: $currentChannelFromProvider');
      
      if (autoJoinChannels.isNotEmpty) {
        // Si hay canales guardados, hacer JOIN a todos ellos después de conectarse
        print('🔍 [AUTOJOIN] ✅ Hay ${autoJoinChannels.length} canales para autojoin: $autoJoinChannels');
        
        // Esperar a que la conexión esté completamente establecida antes de hacer JOIN
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted && ircService.isConnected) {
            // Hacer JOIN a cada canal con un pequeño delay
            for (int i = 0; i < autoJoinChannels.length; i++) {
              final channelToJoin = autoJoinChannels[i];
              Future.delayed(Duration(milliseconds: 500 + (i * 300)), () {
                if (mounted && ircService.isConnected) {
                  print('🔍 [AUTOJOIN] Uniéndose a canal: $channelToJoin');
                  ircService.joinChannel(channelToJoin);
                }
              });
            }
            
            // Establecer el canal actual como el primero de la lista (o el que estaba antes)
            final channelToSet = currentChannelFromProvider ?? autoJoinChannels.first;
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                ref.read(currentChannelProvider.notifier).state = channelToSet;
                print('🔍 [AUTOJOIN] Canal actual establecido: $channelToSet');
              }
            });
          }
        });
      } else {
        // Si no hay canales guardados, usar el canal del formulario (comportamiento normal)
        ref.read(currentChannelProvider.notifier).state = normalizedChannel;
        print('🔍 [CONNECT] Usando canal del formulario: $normalizedChannel');
      }
      // globalLog('🔵 [LOGIN] Set channel in provider: "$channel" -> normalized: "$normalizedChannel"');

      // globalLog('🔵 [LOGIN] About to navigate to ChatScreen');
      
      if (mounted) {
        // globalLog('🔵 [LOGIN] Widget is mounted, navigating...');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const ChatScreen(),
          ),
        );
        // globalLog('🔵 [LOGIN] Navigation completed');
      } else {
        // globalLog('❌ [LOGIN] Widget not mounted, cannot navigate');
      }
    } catch (e, stack) {
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
        title: const Text('Cliente IRC'),
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
                  color: appTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: appTheme.textPrimary.withOpacity(0.3),
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
              appTheme.primary.withOpacity(0.15),
              appTheme.secondary.withOpacity(0.12),
              appTheme.accent.withOpacity(0.08),
              appTheme.background,
            ],
            stops: const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
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
                      appTheme.background.withOpacity(0.95),
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
                        child: Text(
                          'Conectar a GlobalChat IRC Network',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: appTheme.primary,
                          ),
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
                              color: appTheme.primary.withOpacity(0.4),
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
                      value: _selectedServer,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Servidor',
                        prefixIcon: Icon(Icons.language, color: appTheme.primary),
                        labelStyle: TextStyle(color: appTheme.primary),
                        filled: true,
                        fillColor: appTheme.surface.withOpacity(0.9),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withOpacity(0.6), width: 1.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withOpacity(0.4), width: 1),
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
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
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
                      fillColor: appTheme.surface.withOpacity(0.9),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.6), width: 1.5),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: appTheme.primary.withOpacity(0.4), width: 1),
                      ),
                    ),
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
                            color: appTheme.primary.withOpacity(0.7),
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
                        fillColor: appTheme.surface.withOpacity(0.9),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary, width: 2),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withOpacity(0.6), width: 1.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: appTheme.primary.withOpacity(0.4), width: 1),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ChannelSelector(
                    controller: _channelController,
                    channels: _channels,
                    loadingChannels: _loadingChannels,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 24),
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
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_confirmOver14) ? null : _connect,
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
                ],
              ),
            ),
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
                    color: isSelected ? theme.primary : Colors.grey.withOpacity(0.3),
                    width: isSelected ? 2.5 : 1,
                  ),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            theme.primary.withOpacity(0.1),
                            theme.secondary.withOpacity(0.1),
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
                          color: theme.primary.withOpacity(0.4),
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
                            color: widget.appTheme.primary.withOpacity(0.4),
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
      // print('🔍 [DEBUG] _updateFilteredChannels: ${_filteredChannels.length} canales filtrados de ${widget.channels.length} totales');
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
    
    // print('🔍 [DEBUG] _showDropdownOverlay: ${_filteredChannels.length} canales, ${widget.channels.length} totales');
    
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
                  color: widget.appTheme.textSecondary.withOpacity(0.3),
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
                          borderSide: BorderSide(color: widget.appTheme.primary.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: widget.appTheme.primary.withOpacity(0.3)),
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
                                    color: widget.appTheme.primary.withOpacity(0.2),
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
                              // print('🔍 [DEBUG] ✅✅✅✅✅ TAP DETECTADO en canal: ${option.name}');
                              widget.controller.text = option.name;
                              widget.controller.selection = TextSelection(
                                baseOffset: widget.controller.text.length,
                                extentOffset: widget.controller.text.length,
                              );
                              // print('🔍 [DEBUG] Controlador actualizado: "${widget.controller.text}"');
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
          fillColor: widget.appTheme.surface.withOpacity(0.9),
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
            borderSide: BorderSide(color: widget.appTheme.primary.withOpacity(0.6), width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: widget.appTheme.primary.withOpacity(0.4), width: 1),
          ),
        ),
        onTap: () {
          // print('🔍 [DEBUG] onTap del TextField: ${widget.channels.length} canales disponibles');
          if (widget.channels.isNotEmpty) {
            // Si el campo está vacío, asegurar que se muestren todos los canales
            if (widget.controller.text.trim().isEmpty) {
              _updateFilteredChannels();
            }
            // Mostrar el dropdown siempre
            _showDropdownOverlay();
          } else {
            // print('🔍 [DEBUG] ⚠️  No hay canales disponibles aún');
          }
        },
    );
  }
}
