// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return IconButton(
      icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nightlight_round),
      onPressed: () {
        final themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
        // You can replace this with your theme provider or controller
        // Here we use a simple ThemeMode switch for demo purposes
        // For a real app, use Riverpod, Provider, or another state management
        // and set the ThemeMode globally
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Theme toggling requires state management.'),
        ));
      },
    );
  }
}
