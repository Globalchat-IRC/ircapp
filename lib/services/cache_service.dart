import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para gestión de cache y optimización
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Directory? _cacheDir;
  int _maxCacheSize = 100 * 1024 * 1024; // 100MB por defecto
  int _avatarCacheSize = 50 * 1024 * 1024; // 50MB para avatares

  /// Inicializa el servicio de cache
  Future<void> initialize() async {
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    // Cargar configuración
    final prefs = await SharedPreferences.getInstance();
    _maxCacheSize = prefs.getInt('cache_max_size') ?? 100 * 1024 * 1024;
    _avatarCacheSize = prefs.getInt('cache_avatar_size') ?? 50 * 1024 * 1024;

    // Limpiar cache antiguo al iniciar
    await _cleanOldCache();
  }

  /// Obtiene el directorio de cache
  Directory get cacheDir => _cacheDir!;

  /// Guarda datos en cache
  Future<void> saveToCache(String key, List<int> data) async {
    final file = File('${_cacheDir!.path}/$key');
    await file.writeAsBytes(data);
  }

  /// Lee datos del cache
  Future<List<int>?> readFromCache(String key) async {
    final file = File('${_cacheDir!.path}/$key');
    if (await file.exists()) {
      return await file.readAsBytes();
    }
    return null;
  }

  /// Verifica si existe en cache
  Future<bool> existsInCache(String key) async {
    final file = File('${_cacheDir!.path}/$key');
    return await file.exists();
  }

  /// Obtiene el tamaño del cache
  Future<int> getCacheSize() async {
    int totalSize = 0;
    if (await _cacheDir!.exists()) {
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }
    return totalSize;
  }

  /// Limpia cache antiguo
  Future<void> _cleanOldCache() async {
    final currentSize = await getCacheSize();
    if (currentSize > _maxCacheSize) {
      // Limpiar archivos más antiguos hasta estar bajo el límite
      final files = <File>[];
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          files.add(entity);
        }
      }

      // Ordenar por fecha de modificación (más antiguos primero)
      files.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return aStat.modified.compareTo(bStat.modified);
      });

      // Eliminar archivos hasta estar bajo el límite
      int sizeToRemove = currentSize - (_maxCacheSize * 0.8).toInt(); // Dejar 80% del límite
      int removedSize = 0;

      for (final file in files) {
        if (removedSize >= sizeToRemove) break;
        final fileSize = await file.length();
        await file.delete();
        removedSize += fileSize;
      }
    }
  }

  /// Limpia todo el cache
  Future<void> clearCache() async {
    if (await _cacheDir!.exists()) {
      await for (final entity in _cacheDir!.list(recursive: true)) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }

  /// Limpia cache de avatares
  Future<void> clearAvatarCache() async {
    final avatarDir = Directory('${_cacheDir!.path}/avatars');
    if (await avatarDir.exists()) {
      await for (final entity in avatarDir.list(recursive: true)) {
        if (entity is File) {
          await entity.delete();
        }
      }
    }
  }

  /// Configura el tamaño máximo del cache
  Future<void> setMaxCacheSize(int sizeInBytes) async {
    _maxCacheSize = sizeInBytes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('cache_max_size', sizeInBytes);
    await _cleanOldCache();
  }
}




