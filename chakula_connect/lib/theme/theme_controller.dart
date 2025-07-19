import 'package:flutter_riverpod/flutter_riverpod.dart';

final themeControllerProvider = StateNotifierProvider<ThemeController, bool>((ref) {
  return ThemeController();
});

class ThemeController extends StateNotifier<bool> {
  ThemeController() : super(false); // false = light mode

  void toggleTheme() => state = !state;
}
