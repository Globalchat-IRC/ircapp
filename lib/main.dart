import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'screens/login_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'providers/video_provider.dart';
import 'providers/irc_provider.dart';
import 'services/radio_service.dart';
import 'services/chat_history_service.dart';
import 'utils/platform_utils.dart';
import 'models/app_theme.dart';
// En web usa dart:html (reload con forceGet); en nativo usa stub
import 'dart:html' if (dart.library.io) 'package:irc_app/utils/html_stub.dart' as html;

void globalLog(String message) {
  // Logs deshabilitados para producción
  // final timestamp = DateTime.now().toString();
  // final logMessage = '[$timestamp] $message\n';
  // debugPrint(logMessage);
  // print(logMessage);
  
  // Solo escribir a archivo en nativo (no disponible en web)
  // En web simplemente no escribimos a archivo
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // En web: si hay nueva versión desplegada, forzar recarga para salir de caché (usuarios con IP del servidor)
  if (PlatformUtils.isWeb) {
    final didReload = await _checkWebVersionAndReload();
    if (didReload) return;
  }
  
  // Configurar manejo de errores global para evitar errores no capturados
  FlutterError.onError = (FlutterErrorDetails details) {
    // Capturar todos los errores de Flutter
    try {
      // En producción, solo registrar el error sin mostrar UI
      if (kReleaseMode) {
        // Silenciar errores en producción para mejor rendimiento
        // Pero asegurarse de que no se propaguen
        return;
      }
      // En debug, usar el handler por defecto
      FlutterError.presentError(details);
    } catch (e) {
      // Si hay error al manejar el error, al menos evitar que se propague
    }
  };
  
  // Manejar errores de la plataforma (Dart errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      // En producción, capturar y silenciar
      if (kReleaseMode) {
        return true; // Indicar que el error fue manejado
      }
      return false; // En debug, dejar que Flutter maneje el error
    } catch (e) {
      // Si hay error al manejar el error, al menos indicar que fue manejado
      return true;
    }
  };
  
  // En web, también capturar errores de JavaScript
  if (PlatformUtils.isWeb) {
    try {
      // Capturar errores no capturados de JavaScript
      // Esto se hace a través del manejo de errores de Flutter
    } catch (e) {
      // Ignorar errores de configuración
    }
  }
  
  // En web, agregar listeners para detener la radio al cerrar la página
  if (PlatformUtils.isWeb) {
    _setupWebLifecycleListeners();
  }
  
  // Leer parámetro de tema de la URL si estamos en web
  String? urlTheme;
  if (PlatformUtils.isWeb) {
    try {
      final window = html.window;
      final location = window.location;
      final searchParams = location.search ?? '';
      
      if (searchParams.isNotEmpty) {
        final queryString = searchParams.startsWith('?') ? searchParams.substring(1) : searchParams;
        final uri = Uri(query: queryString);
        final themeParam = uri.queryParameters['theme'];
        
        if (themeParam != null && themeParam.trim().isNotEmpty) {
          urlTheme = themeParam.trim();
        }
      }
    } catch (e) {
      // Si hay error, continuar sin tema de URL
    }
  }
  
  runApp(
    ProviderScope(
      child: MyApp(initialTheme: urlTheme),
    ),
  );
}

/// En web, comprueba si el servidor tiene una versión distinta a la actual (nueva versión desplegada).
/// Si es así, fuerza una recarga completa (sin caché) para que el usuario cargue el nuevo bundle
/// y use conexión directa 4443 (IP real visible en el IRC). Devuelve true si se hizo reload.
Future<bool> _checkWebVersionAndReload() async {
  try {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final uri = Uri.base.resolve('version.json?bust=${DateTime.now().millisecondsSinceEpoch}');
    final response = await http.get(uri).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) return false;
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final serverVersion = data?['version'] as String?;
    if (serverVersion == null || serverVersion == currentVersion) return false;
    // Nueva versión desplegada: recarga para cargar el nuevo JS (dart:html reload no acepta argumentos)
    html.window.location.reload();
    return true;
  } catch (_) {
    return false;
  }
}

/// Configurar listeners para detener la radio y limpiar mensajes privados cuando se cierra la página en web
void _setupWebLifecycleListeners() {
  try {
    // Solo ejecutar en web
    if (!PlatformUtils.isWeb) return;
    
    // Detener radio y limpiar mensajes privados cuando la página se oculta o se cierra
    // Usar dynamic para evitar errores de tipo en compilación
    final window = html.window as dynamic;
    
    void cleanup() {
      RadioService().stop();
      // Limpiar mensajes privados usando ProviderScope
      // Esto se hará a través del WidgetsBinding cuando la app se cierre
    }
    
    // onBeforeUnload se dispara antes de cerrar la pestaña/navegador
    // Aquí sí podemos limpiar mensajes privados ya que la app se está cerrando
    if (window.onBeforeUnload != null) {
      window.onBeforeUnload.listen((event) {
        RadioService().stop();
        // Limpiar mensajes privados solo cuando realmente se cierra la pestaña
        // Nota: esto requiere acceso al ref, así que se manejará en dispose()
      });
    }
    
    // onPageHide se dispara cuando se cambia de pestaña, NO limpiar mensajes aquí
    // Solo detener la radio cuando la página se oculta
    if (window.onPageHide != null) {
      window.onPageHide.listen((event) {
        RadioService().stop();
        // NO limpiar mensajes privados aquí - se perderían al cambiar de pestaña
      });
    }
    
    // Detener cuando la página se descarga (cierre de pestaña/navegador)
    // Aquí sí podemos limpiar ya que la app se está cerrando
    if (window.onUnload != null) {
      window.onUnload.listen((event) {
        RadioService().stop();
        // Limpiar mensajes privados solo cuando realmente se cierra la pestaña
        // Nota: esto requiere acceso al ref, así que se manejará en dispose()
      });
    }
  } catch (e) {
    // Si hay algún error, simplemente continuar
    // Esto puede pasar si no estamos en web o si hay problemas con dart:html
  }
}

class MyApp extends ConsumerStatefulWidget {
  final String? initialTheme;
  
  const MyApp({Key? key, this.initialTheme}) : super(key: key);

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // // TEMPORAL (comentado): Borrar historial de privados al arrancar.
    // // Si en el futuro necesitamos reactivarlo, descomentar este bloque.
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   ref.read(messagesProvider.notifier).clearPrivateMessages();
    //   if (!PlatformUtils.isWeb) {
    //     try {
    //       const servers = [
    //         'default',
    //         'ceres.globalchat.org',
    //         'apolo.globalchat.org',
    //         'artemis.globalchat.org',
    //         'caliope.globalchat.org',
    //       ];
    //       for (final server in servers) {
    //         ChatHistoryService().deletePrivateMessages(server: server);
    //       }
    //     } catch (e) {
    //       // Ignorar errores al limpiar
    //     }
    //   }
    // });

    // El tema de la URL ya se maneja en ThemeNotifier._initializeTheme()
    // No necesitamos aplicarlo aquí para evitar conflictos
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Limpiar mensajes privados al cerrar la aplicación
    _cleanupPrivateMessages();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Solo limpiar mensajes privados cuando la app se cierra completamente (detached)
    // NO limpiar cuando solo se pierde el foco (hidden/paused) para preservar los mensajes
    if (state == AppLifecycleState.detached) {
      _cleanupPrivateMessages();
    }
    // Nota: hidden y paused se disparan cuando se cambia de pestaña o se pierde el foco,
    // pero queremos preservar los mensajes privados en esos casos
  }

  void _cleanupPrivateMessages() {
    // Limpiar mensajes privados de la memoria
    ref.read(messagesProvider.notifier).clearPrivateMessages(); // async, pero no esperamos
    
    // Limpiar específicamente mensajes del privado de "nick" y "nickserv"
    final messages = ref.read(messagesProvider);
    final cleanedMessages = messages.where((m) => 
      !(m.channel.toLowerCase() == 'nick' || 
        m.channel.toLowerCase() == 'nickserv' ||
        (m.nick.toLowerCase() == 'nick' && !m.channel.startsWith('#')) ||
        (m.nick.toLowerCase() == 'nickserv' && !m.channel.startsWith('#')))
    ).toList();
    ref.read(messagesProvider.notifier).state = cleanedMessages;
    
    // También limpiar de la base de datos si existe (solo en nativo)
    if (!PlatformUtils.isWeb) {
      try {
        // Limpiar mensajes privados de todos los servidores
        // Obtener todos los servidores posibles y limpiar cada uno
        final servers = ['default', 'ceres.globalchat.org', 'apolo.globalchat.org', 'artemis.globalchat.org'];
        for (final server in servers) {
          ChatHistoryService().deletePrivateMessages(server: server);
        }
      } catch (e) {
        // Ignorar errores al limpiar
      }
    }
  }
  
  void _applyThemeFromUrl(String themeName) {
    try {
      // Buscar el tema por nombre (case-insensitive y sin espacios extra)
      final normalizedThemeName = themeName.trim().toLowerCase();
      AppTheme? foundTheme;
      
      // Buscar en todos los temas
      for (final theme in AppTheme.themes) {
        if (theme.name.toLowerCase().trim() == normalizedThemeName) {
          foundTheme = theme;
          break;
        }
      }
      
      // Solo aplicar si encontramos el tema correcto
      if (foundTheme != null) {
        // Aplicar el tema usando el notifier (esto también guarda en SharedPreferences)
        ref.read(themeProvider.notifier).setTheme(foundTheme);
      }
    } catch (e) {
      // Si hay error, no hacer nada (el provider ya maneja el tema)
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(themeProvider);
    
    // Inicializar el sistema de actualizaciones
    ref.watch(updateProvider);
    
    // Inicializar el servidor de moderación
    ref.watch(moderationServerProvider);
    
    // Inicializar sincronización de reputación con UnrealIRCd
    ref.watch(unrealircdReputationSyncProvider);
    
    // NO inicializar el servicio de radio aquí - se inicializará solo en ChatScreen
    // RadioService().initialize();
    
    final useSystemTheme = appTheme.name == AppTheme.kSystemThemeName;
    final lightTheme = useSystemTheme
        ? AppTheme.themes.firstWhere((t) => t.name == 'Claro', orElse: () => appTheme).toThemeData()
        : appTheme.toThemeData();
    final darkTheme = useSystemTheme
        ? AppTheme.themes.firstWhere((t) => t.name == 'Oscuro', orElse: () => appTheme).toDarkThemeData()
        : appTheme.toDarkThemeData();
    return MaterialApp(
      title: 'Cliente IRC',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: useSystemTheme ? ThemeMode.system : ThemeMode.light,
      home: const LoginScreen(),
    );
  }
}
