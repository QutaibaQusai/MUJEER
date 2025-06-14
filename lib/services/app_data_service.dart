import 'dart:io';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:MUJEER/services/config_service.dart';

class AppDataService {
  static final AppDataService _instance = AppDataService._internal();
  factory AppDataService() => _instance;
  AppDataService._internal();

  // STATIC NOTIFICATION ID - ADD THIS CONSTANT
  static const String NOTIFICATION_ID = '';

  /// Collect app and device data to send to server
  Future<Map<String, String>> collectDataForServer([BuildContext? context]) async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      
      Map<String, String> data = {
        // App Information
        'app_name': packageInfo.appName,
        'app_version': packageInfo.version,
        'build_number': packageInfo.buildNumber,
        'package_name': packageInfo.packageName,
        
        // Platform Information
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
        
        // Timestamps
        'timestamp': DateTime.now().toIso8601String(),
        'timezone': DateTime.now().timeZoneName,
        
        // Source identifier
        'source': 'flutter_app',
        'user_agent': 'ERPForever-Flutter-App/1.0',
        
        // STATIC NOTIFICATION ID - ADD THIS LINE
        'notification_id': NOTIFICATION_ID,
      };

      // Add current language from config
      try {
        final configService = ConfigService();
        if (configService.config != null) {
          // Get language directly from config.json lang property
          data['current_language'] = configService.config!.lang;
          data['text_direction'] = configService.config!.theme.direction;
          debugPrint('📱 Language from config: ${data['current_language']}');
        } else {
          data['current_language'] = 'en'; // Default fallback
          data['text_direction'] = 'LTR';
          debugPrint('⚠️ Config not loaded, using default language: en');
        }
      } catch (e) {
        debugPrint('❌ Error getting language from config: $e');
        data['current_language'] = 'en'; // Default fallback
        data['text_direction'] = 'LTR';
      }

      // Always use dark theme
      data['current_theme_mode'] = 'dark';
      data['theme_setting'] = 'dark';
      debugPrint('🌙 Current theme mode: dark (always)');

      // Add platform-specific data
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        data.addAll({
          'device_brand': androidInfo.brand,
          'device_model': androidInfo.model,
          'device_manufacturer': androidInfo.manufacturer,
          'android_version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt.toString(),
          'is_physical_device': androidInfo.isPhysicalDevice.toString(),
        });
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        data.addAll({
          'device_name': iosInfo.name,
          'device_model': iosInfo.model,
          'system_name': iosInfo.systemName,
          'system_version': iosInfo.systemVersion,
          'is_physical_device': iosInfo.isPhysicalDevice.toString(),
        });
      }

      debugPrint('📊 Collected ${data.length} data fields for server');
      debugPrint('🌍 Language: ${data['current_language']}, Theme: dark (always)');
      debugPrint('🔔 Notification ID: ${data['notification_id']}');
      return data;
      
    } catch (e) {
      debugPrint('❌ Error collecting app data: $e');
      return {
        'error': 'Failed to collect app data',
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'flutter_app',
        'current_language': 'en', // Default fallback
        'current_theme_mode': 'dark', // Always dark
        'notification_id': NOTIFICATION_ID,
      };
    }
  }

  /// Get current language from config with fallback
  String getCurrentLanguage() {
    try {
      final configService = ConfigService();
      if (configService.config != null) {
        // Get language directly from config.json lang property
        return configService.config!.lang;
      }
    } catch (e) {
      debugPrint('❌ Error getting current language: $e');
    }
    return 'en'; // Default fallback
  }

  /// Get current theme mode string - always dark
  String getCurrentThemeMode([BuildContext? context]) {
    return 'dark';
  }

  /// Get the static notification ID
  String getNotificationId() {
    return NOTIFICATION_ID;
  }

  /// Convert data to URL query string
  String dataToQueryString(Map<String, String> data) {
    return data.entries
        .map((entry) => '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
  }

  /// Get compact data for headers (most important fields only)
  Map<String, String> getCompactDataForHeaders([BuildContext? context]) {
    try {
      return {
        'X-App-Language': getCurrentLanguage(),
        'X-App-Theme': 'dark', // Always dark
        'X-Text-Direction': ConfigService().config?.theme.direction ?? 'LTR',
        'X-Platform': Platform.operatingSystem,
        'X-App-Version': '1.0',
        'X-Notification-ID': NOTIFICATION_ID,
      };
    } catch (e) {
      debugPrint('❌ Error creating compact headers: $e');
      return {
        'X-App-Language': 'en',
        'X-App-Theme': 'dark', // Always dark
        'X-Text-Direction': 'LTR',
        'X-Platform': Platform.operatingSystem,
        'X-Notification-ID': NOTIFICATION_ID,
      };
    }
  }
}