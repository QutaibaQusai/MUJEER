// lib/widgets/loading_widget.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:MUJEER/services/config_service.dart';

class LoadingWidget extends StatelessWidget {
  final String message;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final Color? textColor;
  
  const LoadingWidget({
    super.key,
    this.message = "Loading...",
    this.backgroundColor,
    this.indicatorColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        // Get colors from config or use fallbacks
        final configBackgroundColor = _getBackgroundColorFromConfig(configService);
        final configIndicatorColor = _getIndicatorColorFromConfig(configService);
        final configTextColor = _getTextColorFromConfig(configService);
        
        return Container(
          color: backgroundColor ?? configBackgroundColor,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    indicatorColor ?? configIndicatorColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: TextStyle(
                    color: textColor ?? configTextColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Get background color from config with fallback
  Color _getBackgroundColorFromConfig(ConfigService configService) {
    try {
      if (configService.config != null) {
        // Parse the darkBackground color from config
        final darkBg = configService.config!.theme.darkBackground;
        return _hexToColor(darkBg);
      }
    } catch (e) {
      debugPrint('❌ Error parsing background color from config: $e');
    }
    
    // Fallback to your current dark background color
    return const Color(0xFF1E1E1E);
  }

  /// Get indicator color from config with fallback
  Color _getIndicatorColorFromConfig(ConfigService configService) {
    try {
      if (configService.config != null) {
        // Use primary color for the loading indicator
        final primaryColor = configService.config!.theme.primaryColor;
        return _parseColorFromConfig(primaryColor);
      }
    } catch (e) {
      debugPrint('❌ Error parsing indicator color from config: $e');
    }
    
    // Fallback to white
    return Colors.white;
  }

  /// Get text color from config with fallback
  Color _getTextColorFromConfig(ConfigService configService) {
    // Always use white for text on dark background
    return Colors.white;
  }

  /// Convert hex color string to Color object
  Color _hexToColor(String hexColor) {
    try {
      String cleanHex = hexColor.trim();
      
      // Remove # if present
      if (cleanHex.startsWith('#')) {
        cleanHex = cleanHex.substring(1);
      }
      
      // Add alpha if not present (assume full opacity)
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex';
      }
      
      return Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      debugPrint('❌ Error parsing hex color $hexColor: $e');
      return const Color(0xFF1E1E1E); // Fallback
    }
  }

  /// Parse color from config (handles both hex and 0x formats)
  Color _parseColorFromConfig(String colorValue) {
    try {
      String cleanColor = colorValue.trim();

      if (cleanColor.startsWith('0x')) {
        // Handle 0x format (like "0xFFFAB510")
        cleanColor = cleanColor.substring(2);
        if (cleanColor.length == 6) cleanColor = 'FF$cleanColor';
        return Color(int.parse(cleanColor, radix: 16));
      } else if (cleanColor.startsWith('#')) {
        // Handle hex format (like "#FAB510")
        return _hexToColor(cleanColor);
      } else {
        // Handle plain hex (like "FAB510")
        if (cleanColor.length == 6) cleanColor = 'FF$cleanColor';
        return Color(int.parse(cleanColor, radix: 16));
      }
    } catch (e) {
      debugPrint('❌ Error parsing color $colorValue: $e');
      return Colors.white; // Fallback
    }
  }
}