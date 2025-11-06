import 'package:riverpod/riverpod.dart';

final themeControllerProvider = StateNotifierProvider<ThemeController, bool>((ref) {
  return ThemeController();
});

class ThemeController extends StateNotifier<bool> {
  ThemeController() : super(false); // false = light mode

  void toggleTheme() => state = !state;
}
