import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/update_provider.dart';
import 'providers/video_provider.dart';
import 'providers/irc_provider.dart';
import 'services/radio_service.dart';
import 'services/chat_history_service.dart';
import 'utils/platform_utils.dart';
import 'models/app_theme.dart';
// Conditional import for web page lifecycle events
import 'dart:html' if (dart.library.io) 'dart:io' as html;

void globalLog(String message) {
  // Logs deshabilitados para producción
  // final timestamp = DateTime.now().toString();
  // final logMessage = '[$timestamp] $message\n';
  // debugPrint(logMessage);
  // print(logMessage);
  
  // Solo escribir a archivo en nativo (no disponible en web)
  // En web simplemente no escribimos a archivo
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
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
    
    if (window.onBeforeUnload != null) {
      window.onBeforeUnload.listen((event) {
        cleanup();
      });
    }
    
    // También detener cuando la página pierde visibilidad
    if (window.onPageHide != null) {
      window.onPageHide.listen((event) {
        cleanup();
      });
    }
    
    // Detener cuando la página se descarga (cierre de pestaña/navegador)
    if (window.onUnload != null) {
      window.onUnload.listen((event) {
        cleanup();
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
    
    // Aplicar tema de la URL si está presente
    if (widget.initialTheme != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyThemeFromUrl(widget.initialTheme!);
      });
    }
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
    // Cuando la app se cierra o se oculta, limpiar mensajes privados
    if (state == AppLifecycleState.detached || 
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      _cleanupPrivateMessages();
    }
  }

  void _cleanupPrivateMessages() {
    // Limpiar mensajes privados de la memoria
    ref.read(messagesProvider.notifier).clearPrivateMessages();
    
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
      // Buscar el tema por nombre (case-insensitive)
      final theme = AppTheme.themes.firstWhere(
        (t) => t.name.toLowerCase() == themeName.toLowerCase(),
        orElse: () => AppTheme.themes[0], // Fallback al tema por defecto
      );
      
      // Aplicar el tema usando el notifier
      ref.read(themeProvider.notifier).setTheme(theme);
    } catch (e) {
      // Si hay error, usar el tema por defecto
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
    
    return MaterialApp(
      title: 'Cliente IRC',
      theme: appTheme.toThemeData(),
      darkTheme: appTheme.toDarkThemeData(),
      themeMode: ThemeMode.light,
      home: const LoginScreen(),
    );
  }
}
