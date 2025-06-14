// lib/services/theme_service.dart - UPDATED: Always dark theme
import 'package:flutter/material.dart';

class ThemeService extends ChangeNotifier {
  // Always use dark theme
  ThemeMode get themeMode => ThemeMode.dark;

  ThemeService() {
    // No need to load theme mode since it's always dark
    debugPrint('🌙 ThemeService initialized - Always dark theme');
  }

  // Removed getSavedThemeMode method since theme is always dark

  // Keep this method for compatibility but it won't change anything
  Future<void> updateThemeMode(String mode) async {
    debugPrint('🌙 Theme change requested to: $mode - Ignored (always dark)');
    // Do nothing - theme is always dark
  }

  // Helper method to check if dark theme
  bool get isDarkMode => true;

  // Helper method for backwards compatibility
  String get currentThemeMode => 'dark';
}