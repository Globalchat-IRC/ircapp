import 'package:riverpod/legacy.dart';

class SplitViewManager extends StateNotifier<bool> {
  SplitViewManager() : super(false);

  void toggle() => state = !state;
  void enable() => state = true;
  void disable() => state = false;
}

final splitViewProvider = StateNotifierProvider<SplitViewManager, bool>((ref) {
  return SplitViewManager();
});

final splitChannelProvider = StateProvider<String?>((ref) => null);
