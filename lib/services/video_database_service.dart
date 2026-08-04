import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_role.dart';

/// Stub de VideoDatabaseService para web (usa SharedPreferences)
class VideoDatabaseService {
  static final VideoDatabaseService instance = VideoDatabaseService._internal();
  VideoDatabaseService._internal();

  Future<void> get database async {
    throw UnsupportedError('Base de datos local no disponible en web');
  }

  Future<void> init() async {}
  Future<void> close() async {}

  Future<UserProfile?> getUserProfile(String nick) async => null;
  Future<void> saveUserProfile(UserProfile profile) async {}
  Future<void> updateReputation(String nick, int reputation, String reason) async {}
  Future<int> sendEmailVerification(String nick, String email) async => 0;
  Future<bool> verifyEmailCode(String nick, String code) async => false;
  Future<List<Map<String, dynamic>>> getReputationHistory(String nick, {int limit = 20}) async => [];
  Future<List<Map<String, dynamic>>> getConferencesHistory({required String nick, int limit = 20}) async => [];
}
