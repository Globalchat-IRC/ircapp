import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/platform_utils.dart';
// Conditional import for Platform (native only)
import 'dart:io' if (dart.library.html) 'dart:html' as io;

/// Servicio de actualización automática
/// Verifica si hay nuevas versiones disponibles en GitHub Releases
class UpdateService {
  // Configuración de GitHub
  static const String githubOwner = 'Globalchat-IRC'; // Organización de GitHub
  static const String githubRepo = 'ircapp'; // Nombre del repositorio
  static const String githubApiUrl = 'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  
  // Configuración de actualización
  static const Duration checkInterval = Duration(hours: 24); // Verificar cada 24 horas
  static DateTime? _lastCheckTime;
  
  /// Obtener información del paquete actual
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }
  
  /// Verificar si hay actualizaciones disponibles
  Future<UpdateInfo?> checkForUpdates({bool forceCheck = false}) async {
    try {
      // print('🔍 [UPDATE] Verificando actualizaciones...');
      
      // Verificar si ya se revisó recientemente (a menos que sea forzado)
      if (!forceCheck && _lastCheckTime != null) {
        final timeSinceLastCheck = DateTime.now().difference(_lastCheckTime!);
        if (timeSinceLastCheck < checkInterval) {
          // print('⏳ [UPDATE] Última verificación hace ${timeSinceLastCheck.inMinutes} minutos');
          return null;
        }
      }
      
      _lastCheckTime = DateTime.now();
      
      // Obtener versión actual
      final currentVersion = await getCurrentVersion();
      // print('📱 [UPDATE] Versión actual: $currentVersion');
      
      // Consultar GitHub API
      final response = await http.get(
        Uri.parse(githubApiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'IRC-App-Updater',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final latestVersion = (data['tag_name'] as String).replaceAll('v', '');
        final releaseUrl = data['html_url'] as String;
        final releaseNotes = data['body'] as String? ?? 'Sin notas de la versión';
        final publishedAt = DateTime.parse(data['published_at'] as String);
        
        // print('🌐 [UPDATE] Última versión disponible: $latestVersion');
        
        // Buscar el asset del instalador según la plataforma
        String? downloadUrl;
        final assets = data['assets'] as List;
        
        // En web, no buscar actualizaciones descargables
        if (!PlatformUtils.isWeb) {
          for (var asset in assets) {
            final name = asset['name'] as String;
            
            // Buscar instalador según la plataforma (solo en nativo)
            bool isCorrectPlatform = false;
            // ignore: avoid_web_libraries_in_flutter
            try {
              // En nativo, io será dart:io con Platform
              if (_isWindowsFile(name)) {
                isCorrectPlatform = true;
              } else if (_isMacOSFile(name)) {
                isCorrectPlatform = true;
              } else if (_isLinuxFile(name)) {
                isCorrectPlatform = true;
              }
            } catch (e) {
              // Si falla, no es la plataforma correcta
              isCorrectPlatform = false;
            }
            
            if (isCorrectPlatform) {
              downloadUrl = asset['browser_download_url'] as String;
              // print('📦 [UPDATE] Encontrado instalador: $name');
              break;
            }
          }
        }
        
        // Comparar versiones
        if (_isNewerVersion(currentVersion, latestVersion)) {
          // print('✅ [UPDATE] Nueva versión disponible!');
          return UpdateInfo(
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadUrl: downloadUrl ?? releaseUrl,
            releaseNotes: releaseNotes,
            releaseUrl: releaseUrl,
            publishedAt: publishedAt,
            hasDirectDownload: downloadUrl != null,
          );
        } else {
          // print('✓ [UPDATE] Ya estás en la última versión');
          return null;
        }
      } else {
        // print('⚠️ [UPDATE] Error al consultar GitHub: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      // print('❌ [UPDATE] Error verificando actualizaciones: $e');
      return null;
    }
  }
  
  // Helpers para verificar tipo de archivo (deshabilitado en web)
  bool _isWindowsFile(String name) {
    if (PlatformUtils.isWeb) return false;
    // Funcionalidad deshabilitada temporalmente
    return false;
  }
  
  bool _isMacOSFile(String name) {
    if (PlatformUtils.isWeb) return false;
    // Funcionalidad deshabilitada temporalmente
    return false;
  }
  
  bool _isLinuxFile(String name) {
    if (PlatformUtils.isWeb) return false;
    // Funcionalidad deshabilitada temporalmente
    return false;
  }

  /// Comparar dos versiones en formato semántico (1.0.0)
  bool _isNewerVersion(String current, String latest) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final latestParts = latest.split('.').map(int.parse).toList();
      
      // Asegurar que ambas tengan 3 partes
      while (currentParts.length < 3) currentParts.add(0);
      while (latestParts.length < 3) latestParts.add(0);
      
      // Comparar major.minor.patch
      for (var i = 0; i < 3; i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
      
      return false; // Son iguales
    } catch (e) {
      // print('⚠️ [UPDATE] Error comparando versiones: $e');
      return false;
    }
  }
  
  /// Descargar actualización (abre el navegador o descarga el archivo)
  Future<bool> downloadUpdate(UpdateInfo updateInfo) async {
    try {
      if (updateInfo.hasDirectDownload) {
        // print('💾 [UPDATE] Abriendo descarga del instalador...');
        
        // Abrir URL de descarga en el navegador (funciona para Windows, macOS y Linux)
        final uri = Uri.parse(updateInfo.downloadUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          // print('❌ [UPDATE] No se pudo abrir el navegador');
          return false;
        }
      } else {
        // Abrir página de releases
        // print('🌐 [UPDATE] Abriendo página de releases...');
        final uri = Uri.parse(updateInfo.releaseUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          // print('❌ [UPDATE] No se pudo abrir la página de releases');
          return false;
        }
      }
    } catch (e) {
      // print('❌ [UPDATE] Error al descargar: $e');
      return false;
    }
  }
  
  /// Descargar actualización en segundo plano (avanzado - opcional)
  Future<String?> downloadUpdateInBackground(UpdateInfo updateInfo) async {
    if (!updateInfo.hasDirectDownload) return null;
    
    try {
      // print('💾 [UPDATE] Descargando en segundo plano...');
      
      // DESHABILITADO TEMPORALMENTE
      throw UnsupportedError('Descarga de actualizaciones deshabilitada temporalmente');
      
      // Código deshabilitado - descarga de archivos
    } catch (e) {
      // print('❌ [UPDATE] Error al descargar: $e');
      return null;
    }
  }
  
  /// Instalar actualización (ejecutar instalador)
  Future<bool> installUpdate(String installerPath) async {
    try {
      // DESHABILITADO TEMPORALMENTE
      throw UnsupportedError('Instalación de actualizaciones deshabilitada temporalmente');
    } catch (e) {
      // print('❌ [UPDATE] Error al instalar: $e');
      return false;
    }
  }
}

/// Información de una actualización disponible
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final String releaseUrl;
  final DateTime publishedAt;
  final bool hasDirectDownload;
  
  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.releaseUrl,
    required this.publishedAt,
    required this.hasDirectDownload,
  });
  
  String get versionDifference {
    return '$currentVersion → $latestVersion';
  }
  
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(publishedAt);
    
    if (diff.inDays == 0) return 'Hoy';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 30) return 'Hace ${(diff.inDays / 7).floor()} semanas';
    return publishedAt.toString().substring(0, 10);
  }
}

