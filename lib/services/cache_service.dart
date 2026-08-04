import 'package:shared_preferences/shared_preferences.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<void> initialize() async {}
  Future<void> clearCache() async {}
  Future<void> cleanOldCache() async {}

  Future<int> getCacheSize() async => 0;
  Future<int> get cacheSize async => 0;
}
