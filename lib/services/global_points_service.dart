import 'dart:async';
import 'package:flutter/foundation.dart';

class GlobalPointsService extends ChangeNotifier {
  Timer? _pointsTimer;
  int _points = 0;
  DateTime? _connectTime;
  bool _active = false;

  int get points => _points;
  bool get active => _active;

  bool get canSendGift => true;

  int get giftCooldownRemaining => 0;

  void start() {
    if (_active) return;
    _active = true;
    _connectTime = DateTime.now();
    _points = 0;
    _pointsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _tick());
    notifyListeners();
  }

  void stop() {
    _active = false;
    _pointsTimer?.cancel();
    _pointsTimer = null;
    _connectTime = null;
    _points = 0;
    notifyListeners();
  }

  void _tick() {
    if (_connectTime == null) return;
    final elapsed = DateTime.now().difference(_connectTime!).inMinutes;
    final newPoints = (elapsed * 50).clamp(0, 9999);
    if (newPoints > _points) {
      _points = newPoints;
      notifyListeners();
    }
  }

  bool canAfford(int cost) => _points >= cost;

  void add(int amount) {
    _points += amount;
    if (_points > 9999) _points = 9999;
    notifyListeners();
  }

  bool spend(int amount, {bool isGift = false}) {
    if (_points < amount) return false;
    _points -= amount;
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _pointsTimer?.cancel();
    super.dispose();
  }
}
